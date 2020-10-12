object frmNTFSFiles: TfrmNTFSFiles
  Left = 0
  Top = 0
  Caption = 'NTFS '#25991#20214#25628#32034
  ClientHeight = 662
  ClientWidth = 1094
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -11
  Font.Name = 'Tahoma'
  Font.Style = []
  OldCreateOrder = False
  OnDestroy = FormDestroy
  OnResize = FormResize
  DesignSize = (
    1094
    662)
  PixelsPerInch = 96
  TextHeight = 13
  object lblTip: TLabel
    Left = 443
    Top = 8
    Width = 224
    Height = 15
    Caption = #27491#22312#25628#32034#65292#35831#31245#20505#183#183#183#183#183#183
    Font.Charset = GB2312_CHARSET
    Font.Color = clRed
    Font.Height = -15
    Font.Name = #23435#20307
    Font.Style = [fsBold]
    ParentFont = False
  end
  object lvData: TListView
    Left = 8
    Top = 32
    Width = 1078
    Height = 622
    Anchors = [akLeft, akTop, akRight, akBottom]
    Columns = <
      item
        Caption = #24207#21015
        Width = 100
      end
      item
        Caption = #30913#30424
      end
      item
        Caption = #23376'ID'
        Width = 150
      end
      item
        Caption = #29238'ID'
        Width = 150
      end
      item
        Caption = #25991#20214#21517
        Width = 500
      end>
    Font.Charset = GB2312_CHARSET
    Font.Color = clWindowText
    Font.Height = -13
    Font.Name = #23435#20307
    Font.Style = []
    GridLines = True
    OwnerData = True
    ReadOnly = True
    RowSelect = True
    ParentFont = False
    TabOrder = 0
    ViewStyle = vsReport
    OnData = lvDataData
  end
  object tmrSearchStart: TTimer
    OnTimer = tmrSearchStartTimer
    Left = 48
    Top = 96
  end
  object tmrSearchStop: TTimer
    Enabled = False
    OnTimer = tmrSearchStopTimer
    Left = 52
    Top = 172
  end
  object tmrGetFileFullNameStop: TTimer
    Enabled = False
    OnTimer = tmrGetFileFullNameStopTimer
    Left = 236
    Top = 176
  end
end
