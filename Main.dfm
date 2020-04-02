object Form1: TForm1
  Left = 0
  Top = 0
  Caption = '-'
  ClientHeight = 365
  ClientWidth = 767
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -11
  Font.Name = 'Tahoma'
  Font.Style = []
  OldCreateOrder = False
  OnClose = FormClose
  OnCreate = FormCreate
  OnDestroy = FormDestroy
  PixelsPerInch = 96
  TextHeight = 13
  object Button4: TButton
    Left = 512
    Top = 24
    Width = 75
    Height = 25
    Caption = 'Cancelar'
    TabOrder = 4
    OnClick = Button4Click
  end
  object Button1: TButton
    Left = 240
    Top = 24
    Width = 115
    Height = 25
    Caption = 'Consultar direto'
    TabOrder = 0
    OnClick = Button1Click
  end
  object Button2: TButton
    Left = 392
    Top = 24
    Width = 75
    Height = 25
    Caption = 'Button2'
    TabOrder = 1
    OnClick = Button2Click
  end
  object Button3: TButton
    Left = 504
    Top = 24
    Width = 75
    Height = 25
    Caption = 'Consultar'
    TabOrder = 2
    OnClick = Button3Click
  end
  object DBGrid1: TDBGrid
    Left = 0
    Top = 86
    Width = 729
    Height = 259
    DataSource = DataSource1
    TabOrder = 3
    TitleFont.Charset = DEFAULT_CHARSET
    TitleFont.Color = clWindowText
    TitleFont.Height = -11
    TitleFont.Name = 'Tahoma'
    TitleFont.Style = []
  end
  object Query1: TADOQuery
    Connection = ADOConnection1
    CursorType = ctStatic
    Parameters = <>
    SQL.Strings = (
      '/**/'
      'SELECT top 1000000 a.[DepartmentID]'
      '      ,a.[Name]'
      '      ,a.[GroupName]'
      '      ,a.[ModifiedDate]'
      
        '  FROM [HumanResources].[Department] a join [HumanResources].Emp' +
        'loyee on 1=1 '
      
        '                                       join HumanResources.Shift' +
        ' on 1=1 '
      #9#9#9#9#9#9#9#9#9'   join HumanResources.JobCandidate on 1=1'
      #9#9#9#9#9#9#9#9#9'   join HumanResources.EmployeePayHistory on 1=1'
      #9#9#9#9#9#9#9#9#9'   join HumanResources.Department on 1=1'
      ''
      ''
      '/**/'
      '/*'
      'select 1,'#39'A'#39
      'union all'
      'select 2,'#39'B'#39
      'union all'
      'select 3,'#39'A'#39
      'union all'
      'select 4,'#39'X'#39
      'union all'
      'select 5,'#39'W'#39
      '*/')
    Left = 80
    Top = 8
  end
  object ADOConnection1: TADOConnection
    Connected = True
    ConnectionString = 
      'Provider=SQLNCLI11.1;Password=senhatst;Persist Security Info=Tru' +
      'e;User ID=sa;Initial Catalog=AdventureWorks2017;Data Source=LAPT' +
      'OP-GK2QJ6O0;Use Procedure for Prepare=1;Auto Translate=True;Pack' +
      'et Size=4096;Workstation ID=LAPTOP-GK2QJ6O0;Initial File Name=""' +
      ';Use Encryption for Data=False;Tag with column collation when po' +
      'ssible=False;MARS Connection=False;DataTypeCompatibility=0;Trust' +
      ' Server Certificate=False;Server SPN="";Application Intent=READW' +
      'RITE'
    LoginPrompt = False
    Provider = 'SQLNCLI11.1'
    Left = 16
    Top = 8
  end
  object DataSource1: TDataSource
    DataSet = Query1
    Left = 48
    Top = 8
  end
  object Query2: TADOQuery
    Connection = ADOConnection2
    CursorType = ctStatic
    Parameters = <>
    SQL.Strings = (
      '/**/'
      'SELECT top 1000000 a.[DepartmentID]'
      '      ,a.[Name]'
      '      ,a.[GroupName]'
      '      ,a.[ModifiedDate]'
      
        '  FROM [HumanResources].[Department] a join [HumanResources].Emp' +
        'loyee on 1=1 '
      
        '                                       join HumanResources.Shift' +
        ' on 1=1 '
      #9#9#9#9#9#9#9#9#9'   join HumanResources.JobCandidate on 1=1'
      #9#9#9#9#9#9#9#9#9'   join HumanResources.EmployeePayHistory on 1=1'
      #9#9#9#9#9#9#9#9#9'   join HumanResources.Department on 1=1'
      ''
      ''
      '/**/'
      '/*'
      'select 1,'#39'A'#39
      'union all'
      'select 2,'#39'B'#39
      'union all'
      'select 3,'#39'A'#39
      'union all'
      'select 4,'#39'X'#39
      'union all'
      'select 5,'#39'W'#39
      '*/')
    Left = 696
    Top = 16
  end
  object ADOConnection2: TADOConnection
    Connected = True
    ConnectionString = 
      'Provider=SQLNCLI11.1;Password=senhatst;Persist Security Info=Tru' +
      'e;User ID=sa;Initial Catalog=AdventureWorks2017;Data Source=LAPT' +
      'OP-GK2QJ6O0;Use Procedure for Prepare=1;Auto Translate=True;Pack' +
      'et Size=4096;Workstation ID=LAPTOP-GK2QJ6O0;Initial File Name=""' +
      ';Use Encryption for Data=False;Tag with column collation when po' +
      'ssible=False;MARS Connection=False;DataTypeCompatibility=0;Trust' +
      ' Server Certificate=False;Server SPN="";Application Intent=READW' +
      'RITE'
    LoginPrompt = False
    Provider = 'SQLNCLI11.1'
    Left = 632
    Top = 16
  end
  object DataSource2: TDataSource
    DataSet = Query2
    Left = 664
    Top = 16
  end
end
