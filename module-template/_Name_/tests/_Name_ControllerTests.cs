namespace _NamespacePrefix_._ModuleType_._Name_.Tests
{
  using System;
  using System.Collections.Generic;
  using System.Web.Mvc;
  using Controllers;
  using FakeDb;
  using FluentAssertions;
  using Repositories;
  using Xunit;
  using Foundation.Testing.Attributes;
  using Models;
  using NSubstitute;
  using Pipelines;


  public class _Name_ControllerTests
  {
    [Theory]
    [AutoDbData]
    public void DefaultConstructor_ShouldNotThrow()
    {
      Action act = () => new _Name_Controller();
      act.ShouldNotThrow();
    }

    [Theory]
    [AutoDbData]
    public void Constructor_ShouldNotThrow(I_Name_Repository _Name_Repository)
    {
      Action act = () => new _Name_Controller(_Name_Repository);
      act.ShouldNotThrow();
    }

    // TODO: Implement unit tests for the _Name_Controller
  }
}