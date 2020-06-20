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
  object Button1: TButton
    Left = 221
    Top = 6
    Width = 115
    Height = 25
    Caption = 'Setar Timer'
    TabOrder = 1
    OnClick = Button1Click
  end
  object Memo1: TMemo
    Left = 48
    Top = 56
    Width = 657
    Height = 273
    Lines.Strings = (
      'Memo1')
    TabOrder = 2
  end
end
