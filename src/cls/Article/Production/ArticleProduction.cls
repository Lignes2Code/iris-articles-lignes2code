/// Production d'interopérabilité pour la gestion des articles
/// Comprend un service fichier surveillant un dossier et une opération de sauvegarde
Class Article.Production.ArticleProduction Extends Ens.Production
{

XData ProductionDefinition
{
<Production Name="Article.Production.ArticleProduction" LogGeneralTraceEvents="true">
  <Description>Production Lignes2Code - Import d'articles via surveillance de dossier</Description>
  <ActorPoolSize>2</ActorPoolSize>
  
  <!-- Business Service : Surveillance du dossier d'import -->
  <Item Name="Article.Service.FileService" 
        Category="Article" 
        ClassName="Article.Service.FileService" 
        PoolSize="1" 
        Enabled="true" 
        Foreground="false" 
        InactivityTimeout="0"
        Schedule="">
    <Setting Target="Adapter" Name="FilePath">/home/irisowner/data/input/</Setting>
    <Setting Target="Adapter" Name="FileSpec">*.json</Setting>
    <Setting Target="Adapter" Name="ArchivePath">/home/irisowner/data/output/</Setting>
    <Setting Target="Adapter" Name="CallInterval">5</Setting>
    <Setting Target="Host" Name="TargetConfigName">Article.Operation.SaveArticle</Setting>
  </Item>
  
  <!-- Business Operation : Sauvegarde des articles en base -->
  <Item Name="Article.Operation.SaveArticle" 
        Category="Article" 
        ClassName="Article.Operation.SaveArticle" 
        PoolSize="1" 
        Enabled="true" 
        Foreground="false" 
        InactivityTimeout="0">
  </Item>
  
</Production>
}

}
