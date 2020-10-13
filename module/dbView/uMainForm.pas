unit uMainForm;

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, Vcl.Graphics, Vcl.Controls, Vcl.Forms, Vcl.Dialogs, Vcl.StdCtrls, Vcl.Menus, Vcl.ComCtrls,
  System.StrUtils, System.Variants, System.Classes, System.IniFiles, System.JSON, System.Math, Data.DB, Data.Win.ADODB, Data.Win.ADOConEd,
  XLSReadWriteII5, Xc12Utils5, XLSUtils5, Xc12DataStyleSheet5,
  {SynSQLite3Static, mORMotSQLite3, SynSQLite3, SynCommons, SynTable, mORMot, SynDB, SynDBSQLite3, SynDBMidasVCL,} DB.uCommon;

type
  TfrmDBView = class(TForm)
    btnCreateDBLink: TButton;
    pmCreateDBLink: TPopupMenu;
    mniODBC: TMenuItem;
    mniSQLite: TMenuItem;
    grpAllTables: TGroupBox;
    lstAllTabls: TListBox;
    grpAllFields: TGroupBox;
    lvFieldType: TListView;
    grpViewData: TGroupBox;
    btnSQL: TButton;
    btnExportExcel: TButton;
    ADOConnection1: TADOConnection;
    qryData: TADOQuery;
    lvDataView: TListView;
    dsSQLite3Data: TDataSource;
    dlgSaveExcel: TSaveDialog;
    procedure mniODBCClick(Sender: TObject);
    procedure mniSQLiteClick(Sender: TObject);
    procedure btnSQLClick(Sender: TObject);
    procedure FormCreate(Sender: TObject);
    procedure lstAllTablsClick(Sender: TObject);
    procedure lvDataViewData(Sender: TObject; Item: TListItem);
    procedure btnExportExcelClick(Sender: TObject);
  private
    FbODBCAutoAddField: Boolean;
    procedure GetAllTables_ODBC(adocnn: TADOConnection);
    procedure DispTableFieldType(var strDispFields: string);
    procedure DispTableViewData(const strDispFields: string);
    procedure CreateFieldColumn(const strDisplayFields: string; const bSQLite3: Boolean = False);
    function GetChineseFields(const strTableName, strDisplayFields: string): string;
    { 获取自动增长字段 }
    function GetAutoAddField(const strTableName: String; var strAutoField: string): Boolean;
    procedure DispTableFieldType_ODBC(const strTableName: string; var strDispFields: String);
    procedure DispTableViewData_ODBC(const strTableName, strDispFields: string);
    { 保存到 EXCEL 文件 }
    procedure SaveToXLSX(qry: TADODataSet; const strFileName: string);
  public
    { Public declarations }
  end;

procedure db_ShowDllForm_Plugins(var frm: TFormClass; var strParentModuleName, strModuleName: PAnsiChar); stdcall;

implementation

{$R *.dfm}

procedure db_ShowDllForm_Plugins(var frm: TFormClass; var strParentModuleName, strModuleName: PAnsiChar); stdcall;
begin
  frm                     := TfrmDBView;
  strParentModuleName     := '数据库管理';
  strModuleName           := '数据库查看器';
  Application.Handle      := GetMainFormApplication.Handle;
  Application.Icon.Handle := GetMainFormApplication.Icon.Handle;
end;

function TfrmDBView.GetAutoAddField(const strTableName: String; var strAutoField: string): Boolean;
begin
  Result := False;

  with TADOQuery.Create(nil) do
  begin
    Connection := ADOConnection1;
    SQL.Text   := Format('select colstat, name from syscolumns where id=object_id(%s) and colstat = 1', [QuotedStr(strTableName)]);
    Open;
    if RecordCount > 0 then
    begin
      strAutoField := Fields[1].AsString;
      Result       := True;
    end;
    Free;
  end;
end;

procedure TfrmDBView.lvDataViewData(Sender: TObject; Item: TListItem);
var
  qry        : TDataSet;
  I, intIndex: Integer;
begin
  // if FbSQLite3 then
  // qry := dsSQLite3Data.DataSet
  // else
  qry := TDataSet(qryData);

  if not Assigned(qry) then
    Exit;

  if not qry.Active then
    Exit;

  if qry.RecordCount = 0 then
    Exit;

  if lvDataView.Items.Count = 0 then
    Exit;

  if Item.SubItems.Count <> 0 then
    Exit;

  qry.RecNo := Item.Index + 1;
  // if not FbSQLite3 then
  // begin
  Item.Caption := IfThen(FbODBCAutoAddField, qry.Fields[0].AsString, IntToStr(qry.RecNo));
  intIndex     := IfThen(FbODBCAutoAddField, 1, 0);
  // end
  // else
  // begin
  // Item.Caption := IntToStr(qry.RecNo);
  // intIndex     := 0;
  // end;

  for I := intIndex to qry.Fields.Count - 1 do
  begin
    Item.SubItems.Add(qry.Fields[I].AsString);
  end;
end;

function GetFieldType_ODBC(fd: Data.DB.TField): String;
var
  ft: TFieldType;
begin
  ft := fd.DataType;
  if ft in [ftSmallint, ftInteger, ftWord, ftAutoInc, ftLargeint, ftADT, ftLongWord, ftShortint, ftByte] then
    Result := '整数'
  else if ft in [ftString, ftFixedChar, ftWideString, ftFixedWideChar] then
    Result := '字符串'
  else if ft = ftBoolean then
    Result := '布尔'
  else if ft in [Data.DB.ftFloat, Data.DB.ftCurrency, Data.DB.ftBCD, Data.DB.ftExtended, Data.DB.ftSingle] then
    Result := '浮点数'
  else if ft in [Data.DB.ftDate, Data.DB.ftTime, Data.DB.ftDateTime] then
    Result := '日期'
  else if ft in [ftBytes, ftVarBytes, ftArray] then
    Result := '整数数组'
  else if ft = ftBoolean then
    Result := '布尔'
  else if ft in [Data.DB.ftBlob, ftMemo, ftGraphic, ftFmtMemo, ftParadoxOle, ftDBaseOle, ftTypedBinary, ftCursor, ftWideMemo, ftObject] then
    Result := '二进制'
  else
    Result := '未知'
end;

procedure TfrmDBView.DispTableFieldType_ODBC(const strTableName: string; var strDispFields: String);
var
  qry         : TADOQuery;
  lstFields   : TStringList;
  I           : Integer;
  strFieldName: String;
  strFieldType: String;
begin
  strDispFields := '';
  lstFields     := TStringList.Create;
  qry           := TADOQuery.Create(nil);
  try
    with qry do
    begin
      Connection := ADOConnection1;
      SQL.Text   := 'select * from ' + strTableName + ' where 0=1';
      Open;
      ADOConnection1.GetFieldNames(strTableName, lstFields);
      lvFieldType.Items.BeginUpdate;
      for I := 0 to lstFields.Count - 1 do
      begin
        strFieldName := lstFields.Strings[I];
        strFieldType := GetFieldType_ODBC(qry.FieldByName(strFieldName));

        if (not SameText(strFieldType, '二进制')) and (not SameText(strFieldType, '未知')) then
        begin
          strDispFields := strDispFields + ',' + strFieldName;
        end;

        with lvFieldType.Items.Add do
        begin
          Caption := strFieldName;
          SubItems.Add(strFieldType);
        end;
      end;
      strDispFields := RightStr(strDispFields, Length(strDispFields) - 1);
      lvFieldType.Items.EndUpdate;
    end;
  finally
    lstFields.Free;
    qry.Free;
  end;
end;

// function GetFieldType_SQLite3(fd: TSQLDBColumnDefine): string;
// begin
// if fd.ColumnType = ftUnknown then
// Result := '未知'
// else if fd.ColumnType = ftNull then
// Result := '未知'
// else if fd.ColumnType = ftBlob then
// Result := '二进制'
// else if fd.ColumnType = ftDate then
// Result := '日期'
// else if fd.ColumnType = ftInt64 then
// Result := '长整形'
// else if fd.ColumnType = ftDouble then
// Result := '浮点数'
// else if fd.ColumnType = ftCurrency then
// Result := '货币'
// else if fd.ColumnType = ftDate then
// Result := '日期'
// else if fd.ColumnType = ftUTF8 then
// Result := '字符串'
// else
// Result := '未知'
// end;

// { 获取 SQLite3 表结构 }
// procedure TfrmDBView.DispTableFieldType_SQLite3(const strTableName: string; var strDispFields: String);
// var
// I, Count    : Integer;
// arrFields   : TSQLDBColumnDefineDynArray;
// strFieldType: String;
// begin
// strDispFields := '';
// FSQLite3Props.GetFields(RawUTF8(strTableName), arrFields);
// Count := Length(arrFields);
// for I := 0 to Count - 1 do
// begin
// with lvFieldType.Items.Add do
// begin
// Caption      := string(arrFields[I].ColumnName);
// strFieldType := GetFieldType_SQLite3(arrFields[I]);
// SubItems.Add(strFieldType);
// end;
//
// if (arrFields[I].ColumnType <> ftUnknown) and (arrFields[I].ColumnType <> ftNull) and (arrFields[I].ColumnType <> ftBlob) then
// begin
// strDispFields := strDispFields + ',' + string(arrFields[I].ColumnName);
// end;
// end;
//
// if System.SysUtils.Trim(strDispFields) <> '' then
// begin
// strDispFields := RightStr(strDispFields, Length(strDispFields) - 1);
// end;
// end;

procedure TfrmDBView.DispTableFieldType(var strDispFields: string);
var
  strTableName: String;
begin
  strTableName := lstAllTabls.Items[lstAllTabls.ItemIndex];

  // if FbSQLite3 then
  // DispTableFieldType_SQLite3(strTableName, strDispFields)
  // else
  DispTableFieldType_ODBC(strTableName, strDispFields);
end;

function TfrmDBView.GetChineseFields(const strTableName, strDisplayFields: string): string;
const
  c_strFieldChineseName =                                                                                   //
    ' SELECT c.[name] AS 字段名, cast(ep.[value] as varchar(100)) AS [字段说明] FROM sys.tables AS t' +            //
    ' INNER JOIN sys.columns AS c ON t.object_id = c.object_id' +                                           //
    ' LEFT JOIN sys.extended_properties AS ep ON ep.major_id = c.object_id AND ep.minor_id = c.column_id' + //
    ' WHERE ep.class = 1 AND t.name=%s';
var
  strFields      : TArray<String>;
  I              : Integer;
  strChineseField: string;
begin
  with TADOQuery.Create(nil) do
  begin
    Connection := ADOConnection1;
    SQL.Text   := Format(c_strFieldChineseName, [QuotedStr(strTableName)]);
    Open;
    strFields := strDisplayFields.Split([',']);
    for I     := 0 to Length(strFields) - 1 do
    begin
      if Locate('字段名', strFields[I], []) then
      begin
        strChineseField := Fields[1].AsString;
        if System.SysUtils.Trim(strChineseField) <> '' then
          Result := Result + '|' + strChineseField
        else
          Result := Result + '|' + strFields[I];
      end
      else
      begin
        Result := Result + '|' + strFields[I];
      end;
    end;

    if Result <> '' then
    begin
      Result := RightStr(Result, Length(Result) - 1);
    end;

    Free;
  end;
end;

procedure TfrmDBView.CreateFieldColumn(const strDisplayFields: string; const bSQLite3: Boolean = False);
var
  strFields       : TArray<string>;
  I, Count        : Integer;
  strChineseFields: String;
begin
  if not bSQLite3 then
    strChineseFields := GetChineseFields(lstAllTabls.Items[lstAllTabls.ItemIndex], strDisplayFields)
  else
    strChineseFields := StringReplace(strDisplayFields, ',', '|', [rfReplaceAll]);

  lvDataView.Columns.BeginUpdate;
  try
    with lvDataView.Columns.Add do
    begin
      Caption := '序列';
      Width   := 140;
    end;

    strFields := strChineseFields.Split(['|']);
    Count     := Length(strFields);
    for I     := 0 to Count - 1 do
    begin
      with lvDataView.Columns.Add do
      begin
        Caption := strFields[I];
        Width   := 140;
      end;
    end;
  finally
    lvDataView.Columns.EndUpdate;
  end;
end;

// procedure TfrmDBView.DispTableViewData_SQLite3(const strTableName, strDispFields: string);
// begin
// CreateFieldColumn(strDispFields, True);
//
// dsSQLite3Data.DataSet                                     := TSynDBDataSet.Create(self);
// TSynDBDataSet(dsSQLite3Data.DataSet).Connection           := FSQLite3Props;
// TSynDBDataSet(dsSQLite3Data.DataSet).CommandText          := 'select ' + strDispFields + ' from ' + strTableName;
// TSynDBDataSet(dsSQLite3Data.DataSet).IgnoreColumnDataSize := True;
// dsSQLite3Data.DataSet.Open;
// lvDataView.Items.Count := dsSQLite3Data.DataSet.RecordCount;
// end;

procedure TfrmDBView.DispTableViewData_ODBC(const strTableName, strDispFields: string);
var
  strAutoField: String;
begin
  qryData.SQL.Clear;
  qryData.Close;
  if GetAutoAddField(strTableName, strAutoField) then
  begin
    { 有自增长字段 }
    FbODBCAutoAddField := True;
    qryData.SQL.Text   := 'select ROW_NUMBER() over(order by ' + strAutoField + ') as RowNum, ' + strDispFields + ' from ' + strTableName;
  end
  else
  begin
    { 无自增长字段 }
    FbODBCAutoAddField := False;
    qryData.SQL.Text   := 'select Top 1000 ' + strDispFields + ' from ' + strTableName;
  end;

  qryData.Open;
  if qryData.RecordCount > 0 then
  begin
    CreateFieldColumn(strDispFields);
    lvDataView.Items.Count := qryData.RecordCount;
  end;
end;

procedure TfrmDBView.DispTableViewData(const strDispFields: string);
var
  strTableName: string;
begin
  strTableName := lstAllTabls.Items[lstAllTabls.ItemIndex];
  // if FbSQLite3 then
  // DispTableViewData_SQLite3(strTableName, strDispFields)
  // else
  DispTableViewData_ODBC(strTableName, strDispFields);
end;

procedure TfrmDBView.FormCreate(Sender: TObject);
begin
  if qryData.Connection = nil then
  begin
    qryData.Connection := ADOConnection1;
  end
  else
  begin
    btnCreateDBLink.Caption := '断开数据库连接';
    GetAllTables_ODBC(qryData.Connection);
    ADOConnection1 := qryData.Connection;
  end;
end;

procedure TfrmDBView.mniODBCClick(Sender: TObject);
begin
  qryData.Close;
  if Assigned(dsSQLite3Data.DataSet) then
    dsSQLite3Data.DataSet.Active := False;
  // FbSQLite3                      := False;
  ADOConnection1.Connected := False;
  if EditConnectionString(ADOConnection1) then
  begin
    GetAllTables_ODBC(ADOConnection1);
    btnSQL.Enabled         := True;
    btnExportExcel.Enabled := True;
  end;
end;

// procedure TfrmDBView.GetAllTables_SQLite3;
// var
// arrTable: TRawUTF8DynArray;
// I       : Integer;
// begin
// FSQLite3Props.GetTableNames(arrTable);
// for I := 0 to Length(arrTable) - 1 do
// begin
// if Trim(arrTable[I]) <> '' then
// begin
// lstAllTabls.Items.Add(string(arrTable[I]));
// end;
// end;
// end;

// procedure TfrmDBView.OpenSQLite3(const strFileName: string);
// begin
// lstAllTabls.Clear;
// qryData.Close;
// lvFieldType.Clear;
// lvDataView.Clear;
// lvDataView.Columns.Clear;
// lvDataView.Items.Clear;
//
// if Assigned(FSQLite3Props) then
// begin
// FSQLite3Props.Free;
// FSQLite3Props := nil;
// end;
//
// FSQLite3Props := TSQLDBSQLite3ConnectionProperties.Create(StringToUTF8(strFileName), '', '', '');
// GetAllTables_SQLite3;
// end;

procedure TfrmDBView.mniSQLiteClick(Sender: TObject);
// var
// strSQLite3FileName: String;
begin
  // qryData.Close;
  // if Assigned(dsSQLite3Data.DataSet) then
  // dsSQLite3Data.DataSet.Active := False;
  // FbSQLite3                      := True;
  // with TOpenDialog.Create(nil) do
  // begin
  // Filter := 'SQLite3(*.db)|*.db';
  // if Execute(Handle) then
  // begin
  // strSQLite3FileName := FileName;
  // OpenSQLite3(strSQLite3FileName);
  // btnSQL.Enabled         := True;
  // btnExportExcel.Enabled := True;
  // end;
  // Free;
  // end;
end;

procedure TfrmDBView.GetAllTables_ODBC(adocnn: TADOConnection);
begin
  lstAllTabls.Clear;
  qryData.Close;
  lvFieldType.Clear;
  lvDataView.Clear;
  lvDataView.Columns.Clear;
  lvDataView.Items.Clear;
  adocnn.GetTableNames(lstAllTabls.Items);
end;

procedure TfrmDBView.lstAllTablsClick(Sender: TObject);
var
  strDispFields: String;
begin
  if lstAllTabls.ItemIndex = -1 then
    Exit;

  lvDataView.Items.Count := 0;
  lvDataView.Visible     := False;
  try
    qryData.Close;
    lvFieldType.Clear;
    lvDataView.Clear;
    lvDataView.Columns.Clear;
    lvDataView.Items.Clear;
    DispTableFieldType(strDispFields);
    DispTableViewData(strDispFields);
  finally
    lvDataView.Visible := True;
  end;
end;

procedure TfrmDBView.btnExportExcelClick(Sender: TObject);
begin
  if not dlgSaveExcel.Execute then
    Exit;

  // if not FbSQLite3 then
  // SaveToXLSX(TADODataSet(qryData), dlgSaveExcel.FileName)
  // else
  SaveToXLSX(TADODataSet(dsSQLite3Data.DataSet), dlgSaveExcel.FileName)
end;

{ 保存到 EXCEL 文件 }
procedure TfrmDBView.SaveToXLSX(qry: TADODataSet; const strFileName: string);
var
  XLS    : TXLSReadWriteII5;
  I, J, K: Integer;
  intPos : Integer;
begin
  intPos                  := qry.RecNo;
  btnCreateDBLink.Enabled := False;
  btnSQL.Enabled          := False;
  btnExportExcel.Enabled  := False;
  btnExportExcel.Enabled  := False;
  Application.ProcessMessages;
  XLS := TXLSReadWriteII5.Create(nil);
  try
    XLS.FileName := dlgSaveExcel.FileName + '.xlsx';
    for I        := 1 to lvDataView.Columns.Count - 1 do
    begin
      for J := 1 to qry.RecordCount + 1 do
      begin
        XLS.Sheets[0].Range.Items[I, J, I, J].BorderOutlineStyle := cbsThin;
        XLS.Sheets[0].Range.Items[I, J, I, J].BorderOutlineColor := 0;
      end;
    end;

    for I := 1 to lvDataView.Columns.Count - 1 do
    begin
      Application.ProcessMessages;
      XLS.Sheets[0].AsString[I, 1]                  := lvDataView.Column[I].Caption;
      XLS.Sheets[0].Columns[I].Width                := 4000;
      XLS.Sheets[0].Cell[I, 1].FontColor            := clWhite;
      XLS.Sheets[0].Cell[I, 1].FontStyle            := XLS.Sheets[0].Cell[I, 1].FontStyle + [xfsBold];
      XLS.Sheets[0].Cell[I, 1].FillPatternForeColor := xcBlue;
      XLS.Sheets[0].Cell[I, 1].HorizAlignment       := chaCenter;
      XLS.Sheets[0].Cell[I, 1].VertAlignment        := cvaCenter;
    end;

    K := 2;
    qry.First;
    while not qry.Eof do
    begin
      J     := 1; // IfThen(FbSQLite3, 2, 1);
      for I := 1 to lvDataView.Columns.Count - 2 do
      begin
        XLS.Sheets[0].AsString[J, K]            := qry.Fields[I].AsString;
        XLS.Sheets[0].Cell[J, K].HorizAlignment := chaCenter;
        XLS.Sheets[0].Cell[J, K].VertAlignment  := cvaCenter;
        Inc(J);
      end;
      Inc(K);
      btnExportExcel.Caption := Format('正在导出：%d', [K - 2]);
      qry.Next;
    end;

    XLS.Write;
  finally
    XLS.Free;
    btnExportExcel.Caption  := '导出到 EXCEL 文件';
    btnExportExcel.Enabled  := True;
    btnSQL.Enabled          := True;
    btnCreateDBLink.Enabled := True;
    qry.RecNo               := intPos;
  end;
end;

procedure TfrmDBView.btnSQLClick(Sender: TObject);
begin
  //
end;

end.
