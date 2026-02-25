/// Utilitaire JWT — Génération et validation de tokens
/// Algorithme : HS256 (HMAC-SHA256) implémenté avec les fonctions crypto natives IRIS
Class Article.Auth.JWT [ Abstract ]
{

/// Clé secrète pour signer les tokens
/// À changer en production (variable d'environnement recommandée)
Parameter SECRET = "iris-articles-l2c-jwt-secret-2026-change-me-in-production";

/// Durée de vie du token en secondes (1 heure)
Parameter EXPIRATION = 3600;

/// Encode une chaîne en Base64URL (RFC 7515)
/// Remplace +/ par -_ et retire le padding =
ClassMethod Base64URLEncode(pData As %String) As %String
{
    Set b64 = $System.Encryption.Base64Encode(pData, 1)
    Set b64 = $Translate(b64, "+/=", "-_")
    Return b64
}

/// Décode une chaîne Base64URL vers la valeur originale
ClassMethod Base64URLDecode(pData As %String) As %String
{
    // Restaurer Base64 standard depuis Base64URL
    Set b64 = $Translate(pData, "-_", "+/")
    // Ajouter le padding si nécessaire
    Set mod = $Length(b64) # 4
    If mod = 2 { Set b64 = b64 _ "==" }
    ElseIf mod = 3 { Set b64 = b64 _ "=" }
    Return $System.Encryption.Base64Decode(b64)
}

/// Génère un token JWT pour un utilisateur authentifié
/// pUsername : nom d'utilisateur (claim "sub")
/// pRoles : rôles de l'utilisateur (claim "roles")
ClassMethod GenerateToken(pUsername As %String, pRoles As %String = "") As %String
{
    // Header (fixe pour HS256)
    Set header = {"alg":"HS256","typ":"JWT"}
    Set headerB64 = ..Base64URLEncode(header.%ToJSON())
    
    // Payload avec timestamps Unix
    // Calcul Unix timestamp : $Horolog donne (jours depuis 31/12/1840, secondes dans la journée)
    // Époque Unix = 1er janvier 1970 = jour 47117 dans $Horolog
    Set hDays = $Piece($Horolog, ",", 1)
    Set hSecs = $Piece($Horolog, ",", 2)
    Set nowUnix = ((hDays - 47117) * 86400) + hSecs
    Set expUnix = nowUnix + ..#EXPIRATION
    
    Set payload = {}
    Set payload.sub = pUsername
    Set payload.iat = nowUnix
    Set payload.exp = expUnix
    Set payload.roles = pRoles
    Set payload.iss = "iris-articles-lignes2code"
    Set payloadB64 = ..Base64URLEncode(payload.%ToJSON())
    
    // Signature HMAC-SHA256
    Set signingInput = headerB64 _ "." _ payloadB64
    Set signature = $System.Encryption.HMACSHA(256, signingInput, ..#SECRET)
    Set signatureB64 = ..Base64URLEncode(signature)
    
    Return signingInput _ "." _ signatureB64
}

/// Valide un token JWT : vérifie la structure, la signature et l'expiration
/// Retourne le payload (%DynamicObject) si valide, "" sinon
/// pStatus contient le détail de l'erreur en cas d'échec
ClassMethod ValidateToken(pToken As %String, Output pStatus As %Status) As %DynamicObject
{
    Set pStatus = $$$OK
    
    Try {
        // Vérifier la structure (3 parties séparées par des points)
        If $Length(pToken, ".") '= 3 {
            Set pStatus = $$$ERROR($$$GeneralError, "Format de token invalide")
            Return ""
        }
        
        Set headerB64 = $Piece(pToken, ".", 1)
        Set payloadB64 = $Piece(pToken, ".", 2)
        Set signatureB64 = $Piece(pToken, ".", 3)
        
        // Vérifier la signature
        Set signingInput = headerB64 _ "." _ payloadB64
        Set expectedSig = $System.Encryption.HMACSHA(256, signingInput, ..#SECRET)
        Set expectedSigB64 = ..Base64URLEncode(expectedSig)
        
        If signatureB64 '= expectedSigB64 {
            Set pStatus = $$$ERROR($$$GeneralError, "Signature invalide")
            Return ""
        }
        
        // Décoder le payload
        Set payloadJSON = ..Base64URLDecode(payloadB64)
        Set payload = {}.%FromJSON(payloadJSON)
        
        // Vérifier l'expiration
        Set hDays = $Piece($Horolog, ",", 1)
        Set hSecs = $Piece($Horolog, ",", 2)
        Set nowUnix = ((hDays - 47117) * 86400) + hSecs
        If payload.exp < nowUnix {
            Set pStatus = $$$ERROR($$$GeneralError, "Token expiré")
            Return ""
        }
        
        Return payload
    }
    Catch ex {
        Set pStatus = ex.AsStatus()
        Return ""
    }
}

/// Extrait le token Bearer du header Authorization de la requête HTTP courante
/// Format attendu : "Bearer <token>"
/// Retourne "" si absent ou mal formé
ClassMethod ExtractBearerToken(pRequest As %CSP.Request) As %String
{
    Set authHeader = pRequest.GetCgiEnv("HTTP_AUTHORIZATION")
    If authHeader = "" Return ""
    
    // Vérifier le préfixe "Bearer "
    If $Extract(authHeader, 1, 7) '= "Bearer " Return ""
    
    Return $Extract(authHeader, 8, *)
}

}
