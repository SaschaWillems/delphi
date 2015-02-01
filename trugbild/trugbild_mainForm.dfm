object GLForm: TGLForm
  Left = 196
  Top = 108
  Caption = 'Trugbild - '#169' 2013 by Sascha Willems (www.saschawillems.de)'
  ClientHeight = 720
  ClientWidth = 1280
  Color = clBlack
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -11
  Font.Name = 'MS Sans Serif'
  Font.Style = []
  OldCreateOrder = False
  Position = poDesktopCenter
  OnClick = FormClick
  OnCloseQuery = FormCloseQuery
  OnCreate = FormCreate
  OnDestroy = FormDestroy
  OnKeyPress = FormKeyPress
  OnMouseMove = FormMouseMove
  OnResize = FormResize
  OnShow = FormShow
  PixelsPerInch = 96
  TextHeight = 13
  object TimerStartGame: TTimer
    Enabled = False
    Interval = 25
    OnTimer = TimerStartGameTimer
    Left = 40
    Top = 32
  end
end
