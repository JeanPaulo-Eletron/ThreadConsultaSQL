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
  PixelsPerInch = 96
  TextHeight = 13
  object ComboBox1: TComboBox
    Left = 584
    Top = 10
    Width = 145
    Height = 21
    TabOrder = 0
    Text = 'ComboBox1'
    OnChange = ComboBox1Change
  end
  object DBGrid1: TDBGrid
    Left = 0
    Top = 86
    Width = 729
    Height = 259
    TabOrder = 1
    TitleFont.Charset = DEFAULT_CHARSET
    TitleFont.Color = clWindowText
    TitleFont.Height = -11
    TitleFont.Name = 'Tahoma'
    TitleFont.Style = []
    Columns = <
      item
        Expanded = False
        FieldName = 'DepartmentID'
        Visible = True
      end
      item
        Expanded = False
        FieldName = 'GroupName'
        Visible = True
      end
      item
        Expanded = False
        FieldName = 'ModifiedDate'
        Visible = True
      end
      item
        Expanded = False
        FieldName = 'Name'
        Visible = True
      end>
  end
  object Button1: TButton
    Left = 213
    Top = 39
    Width = 115
    Height = 25
    Caption = 'Setar Timer'
    TabOrder = 2
    OnClick = Button1Click
  end
end
