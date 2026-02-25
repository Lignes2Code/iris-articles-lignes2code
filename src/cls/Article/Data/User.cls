/// Classe persistante pour les utilisateurs de l'application
/// Gère l'authentification avec hash SHA-256 itéré + sel aléatoire
Class Article.Data.User Extends (%Persistent, %JSON.Adaptor)
{

/// Nom d'utilisateur (unique, sert de login)
Property Username As %String(MAXLEN = 100) [ Required ];

/// Index unique sur le nom d'utilisateur
Index UsernameIdx On Username [ Unique ];

/// Hash du mot de passe (SHA-256 itéré, jamais stocké en clair)
Property PasswordHash As %String(MAXLEN = 500) [ Required ];

/// Sel aléatoire pour le hash (unique par utilisateur)
Property Salt As %String(MAXLEN = 100) [ Required ];

/// Rôles de l'utilisateur (admin, editor, reader)
Property Roles As %String(MAXLEN = 500) [ InitialExpression = "reader" ];

/// Adresse email
Property Email As %String(MAXLEN = 200);

/// Date de création du compte
Property DateCreated As %TimeStamp [ InitialExpression = {$ZDateTime($Horolog, 3)} ];

/// Compte actif ou désactivé
Property Active As %Boolean [ InitialExpression = 1 ];

/// Mapping JSON pour l'export (sans exposer le hash ni le sel)
XData BasicReference [ XMLNamespace = "http://www.intersystems.com/jsonmapping" ]
{
<Mapping xmlns="http://www.intersystems.com/jsonmapping">
  <Property Name="Username" FieldName="username"/>
  <Property Name="Roles" FieldName="roles"/>
  <Property Name="Email" FieldName="email"/>
  <Property Name="DateCreated" FieldName="dateCreated"/>
  <Property Name="Active" FieldName="active"/>
</Mapping>
}

/// Crée un nouvel utilisateur avec hachage sécurisé du mot de passe
/// pUsername : login unique
/// pPassword : mot de passe en clair (sera hashé)
/// pEmail : adresse email (optionnel)
/// pRoles : rôles séparés par des virgules (défaut: "reader")
ClassMethod CreateUser(pUsername As %String, pPassword As %String, pEmail As %String = "", pRoles As %String = "reader") As %Status
{
    // Vérifier l'unicité du username
    If ..UsernameExists(pUsername) {
        Return $$$ERROR($$$GeneralError, "L'utilisateur '" _ pUsername _ "' existe déjà")
    }
    
    // Validation basique
    If $Length(pPassword) < 6 {
        Return $$$ERROR($$$GeneralError, "Le mot de passe doit faire au moins 6 caractères")
    }
    
    Set user = ..%New()
    Set user.Username = pUsername
    Set user.Email = pEmail
    Set user.Roles = pRoles
    
    // Générer un sel aléatoire (32 octets → Base64)
    Set user.Salt = $System.Encryption.Base64Encode($System.Encryption.GenCryptRand(32), 1)
    
    // Hasher le mot de passe avec le sel
    Set user.PasswordHash = ..HashPassword(pPassword, user.Salt)
    
    Return user.%Save()
}

/// Vérifie si un nom d'utilisateur existe déjà
ClassMethod UsernameExists(pUsername As %String) As %Boolean
{
    &sql(SELECT COUNT(*) INTO :cnt FROM Article_Data."User" WHERE Username = :pUsername)
    Return (cnt > 0)
}

/// Hash un mot de passe avec un sel (SHA-256 itéré 10 000 fois)
/// Le nombre d'itérations ralentit les attaques par force brute
ClassMethod HashPassword(pPassword As %String, pSalt As %String) As %String
{
    Set combined = pSalt _ pPassword
    Set hash = combined
    For i = 1:1:10000 {
        Set hash = $System.Encryption.SHA256Hash(hash)
    }
    Return $System.Encryption.Base64Encode(hash, 1)
}

/// Vérifie les identifiants d'un utilisateur
/// Retourne 1 si OK, 0 si KO
/// pUser contient l'objet User si les identifiants sont valides
ClassMethod VerifyCredentials(pUsername As %String, pPassword As %String, Output pUser As Article.Data.User) As %Boolean
{
    Set pUser = ""
    
    // Chercher l'utilisateur actif
    &sql(SELECT ID INTO :userId FROM Article_Data."User" WHERE Username = :pUsername AND Active = 1)
    If SQLCODE '= 0 Return 0
    
    Set pUser = ..%OpenId(userId)
    If '$IsObject(pUser) Return 0
    
    // Comparer les hash
    Set testHash = ..HashPassword(pPassword, pUser.Salt)
    Return (testHash = pUser.PasswordHash)
}

Storage Default
{
<Data name="UserDefaultData">
<Value name="1">
<Value>%%CLASSNAME</Value>
</Value>
<Value name="2">
<Value>Username</Value>
</Value>
<Value name="3">
<Value>PasswordHash</Value>
</Value>
<Value name="4">
<Value>Salt</Value>
</Value>
<Value name="5">
<Value>Roles</Value>
</Value>
<Value name="6">
<Value>Email</Value>
</Value>
<Value name="7">
<Value>DateCreated</Value>
</Value>
<Value name="8">
<Value>Active</Value>
</Value>
</Data>
<DataLocation>^Article.Data.UserD</DataLocation>
<DefaultData>UserDefaultData</DefaultData>
<IdLocation>^Article.Data.UserD</IdLocation>
<IndexLocation>^Article.Data.UserI</IndexLocation>
<StreamLocation>^Article.Data.UserS</StreamLocation>
<Type>%Storage.Persistent</Type>
}

}

