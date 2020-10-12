object frmDBView: TfrmDBView
  Left = 0
  Top = 0
  Caption = #25968#25454#24211#25968#25454#27983#35272' v2.0'
  ClientHeight = 636
  ClientWidth = 1044
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -11
  Font.Name = 'Tahoma'
  Font.Style = []
  OldCreateOrder = False
  Position = poScreenCenter
  OnCreate = FormCreate
  DesignSize = (
    1044
    636)
  PixelsPerInch = 96
  TextHeight = 13
  object btnCreateDBLink: TButton
    Left = 8
    Top = 8
    Width = 225
    Height = 33
    Caption = #21019#24314#25968#25454#24211#36830#25509
    DropDownMenu = pmCreateDBLink
    Style = bsSplitButton
    TabOrder = 0
    OnClick = mniODBCClick
  end
  object grpAllTables: TGroupBox
    Left = 8
    Top = 52
    Width = 225
    Height = 576
    Anchors = [akLeft, akTop, akBottom]
    Caption = #25152#26377#34920#65306
    TabOrder = 1
    DesignSize = (
      225
      576)
    object lstAllTabls: TListBox
      Left = 8
      Top = 15
      Width = 209
      Height = 550
      Anchors = [akLeft, akTop, akRight, akBottom]
      BevelInner = bvNone
      BevelOuter = bvNone
      ItemHeight = 13
      TabOrder = 0
      OnClick = lstAllTablsClick
    end
  end
  object grpAllFields: TGroupBox
    Left = 239
    Top = 52
    Width = 225
    Height = 576
    Anchors = [akLeft, akTop, akBottom]
    Caption = #25152#26377#23383#27573#65306
    TabOrder = 2
    DesignSize = (
      225
      576)
    object lvFieldType: TListView
      Left = 8
      Top = 15
      Width = 205
      Height = 550
      Anchors = [akLeft, akTop, akRight, akBottom]
      Columns = <
        item
          Caption = #21517#31216
          Width = 80
        end
        item
          Caption = #31867#22411
          Width = 100
        end>
      GridLines = True
      ReadOnly = True
      RowSelect = True
      TabOrder = 0
      ViewStyle = vsReport
    end
  end
  object grpViewData: TGroupBox
    Left = 470
    Top = 52
    Width = 566
    Height = 576
    Anchors = [akLeft, akTop, akRight, akBottom]
    Caption = #25968#25454#27983#35272#65306
    TabOrder = 3
    DesignSize = (
      566
      576)
    object lvDataView: TListView
      Left = 8
      Top = 15
      Width = 545
      Height = 550
      Anchors = [akLeft, akTop, akRight, akBottom]
      Columns = <>
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
      OnData = lvDataViewData
    end
  end
  object btnSQL: TButton
    Left = 470
    Top = 8
    Width = 105
    Height = 33
    Caption = #33258#23450#20041'SQL'#26597#35810
    Enabled = False
    TabOrder = 4
    OnClick = btnSQLClick
  end
  object btnExportExcel: TButton
    Left = 920
    Top = 8
    Width = 116
    Height = 33
    Anchors = [akTop, akRight]
    Caption = #23548#20986#21040' EXCEL '#25991#20214
    Enabled = False
    TabOrder = 5
    OnClick = btnExportExcelClick
  end
  object pmCreateDBLink: TPopupMenu
    Left = 560
    Top = 244
    object mniODBC: TMenuItem
      Caption = 'ODBC '#36830#25509
      OnClick = mniODBCClick
    end
    object mniSQLite: TMenuItem
      Caption = 'SQLite '#36830#25509
      OnClick = mniSQLiteClick
    end
  end
  object ADOConnection1: TADOConnection
    Left = 96
    Top = 176
  end
  object qryData: TADOQuery
    Parameters = <>
    Left = 96
    Top = 260
  end
  object dsSQLite3Data: TDataSource
    Left = 566
    Top = 324
  end
  object dlgSaveExcel: TSaveDialog
    Filter = 'EXCEL(*.XLSX)|*.XLSX'
    Left = 566
    Top = 396
  end
end
