namespace _NamespacePrefix_._ModuleType_._Name_.Controllers
{
  using System;
  using System.Web.Mvc;
  using Sitecore.Data;
  using Repositories;

  public class _Name_Controller : Sitecore.Mvc.Controllers.SitecoreController
  {
    private readonly I_Name_Repository _Name_Repository;

    public _Name_Controller() : this(new _Name_Repository())
    {
    }

    public _Name_Controller(I_Name_Repository _Name_Repository)
    {
      this._Name_Repository = _Name_Repository;
    }

    public ActionResult _Name_()
    {
        /* 
          TODO: Use the repository to retrieve model data 
          which can be passed into the view.
        */

       //var model = _Name_Repository. ;
       //
       //return this.View(model);
       
       throw new NotImplementedException();
    }
  }
}