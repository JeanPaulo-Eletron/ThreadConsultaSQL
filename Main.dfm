object FormMain: TFormMain
  Left = 0
  Top = 0
  ClientHeight = 365
  ClientWidth = 767
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -11
  Font.Name = 'Tahoma'
  Font.Style = []
  OldCreateOrder = False
  OnCreate = FormCreate
  OnDestroy = FormDestroy
  PixelsPerInch = 96
  TextHeight = 13
  object lbl1: TLabel
    Left = 128
    Top = 51
    Width = 6
    Height = 13
    Caption = '1'
  end
  object Button4: TButton
    Left = 334
    Top = 8
    Width = 115
    Height = 25
    Caption = 'Cancelar'
    TabOrder = 2
    OnClick = Button4Click
  end
  object Button3: TButton
    Left = 334
    Top = 8
    Width = 115
    Height = 25
    Caption = 'Consultar'
    TabOrder = 0
    OnClick = Button3Click
  end
  object DBGrid1: TDBGrid
    Left = 0
    Top = 86
    Width = 729
    Height = 259
    DataSource = DataSource1
    TabOrder = 1
    TitleFont.Charset = DEFAULT_CHARSET
    TitleFont.Color = clWindowText
    TitleFont.Height = -11
    TitleFont.Name = 'Tahoma'
    TitleFont.Style = []
  end
  object Button5: TButton
    Left = 213
    Top = 8
    Width = 115
    Height = 25
    Caption = 'Contar'
    TabOrder = 3
    OnClick = Button5Click
  end
  object Button7: TButton
    Left = 455
    Top = 8
    Width = 115
    Height = 25
    Caption = 'Timer Thread Assync'
    TabOrder = 4
    OnClick = Button7Click
  end
  object Button1: TButton
    Left = 455
    Top = 58
    Width = 115
    Height = 25
    Caption = 'Stop'
    TabOrder = 5
    OnClick = Button1Click
  end
  object Button2: TButton
    Left = 455
    Top = 33
    Width = 115
    Height = 25
    Caption = 'Start'
    TabOrder = 6
    OnClick = Button2Click
  end
  object Query1: TADOQuery
    Connection = ADOConnection1
    CursorType = ctStatic
    Parameters = <>
    SQL.Strings = (
      ''
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
      ''
      '/*'
      'select 1,'#39'A'#39', 1.85'
      'union all'
      'select 2,'#39'B'#39', 1.55'
      'union all'
      'select 3,'#39'A'#39', 1.78'
      'union all'
      'select 4,'#39'X'#39', 3.85'
      'union all'
      'select 5,'#39'W'#39', 5.50'
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
end
