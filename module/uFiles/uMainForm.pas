unit uMainForm;

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Variants, System.Classes, System.JSON, System.IOUtils, System.Types, System.Diagnostics, System.Generics.Collections, Vcl.StdCtrls, Vcl.Graphics, Vcl.Controls, Vcl.Forms, Vcl.Dialogs, Vcl.ExtCtrls, Vcl.ComCtrls,
  Data.db, SynSQLite3Static, mORMotSQLite3, SynSQLite3, SynCommons, SynTable, mORMot, SynDB, SynDBSQLite3, SynDBMidasVCL, uThreadSearchDrive, uThreadGetFileFullName, db.uCommon;

type
  TfrmNTFSFiles = class(TForm)
    tmrSearchStart: TTimer;
    lvData: TListView;
    lblTip: TLabel;
    tmrSearchStop: TTimer;
    tmrGetFileFullNameStop: TTimer;
    procedure tmrSearchStartTimer(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure lvDataData(Sender: TObject; Item: TListItem);
    procedure tmrSearchStopTimer(Sender: TObject);
    procedure FormResize(Sender: TObject);
    procedure tmrGetFileFullNameStopTimer(Sender: TObject);
  private
    FDatabase                 : TSQLDataBase;
    FintStartTime             : Cardinal;
    FlstAllDrives             : TStringList;
    FintCount                 : Cardinal;
    FintSearchDriveThreadCount: Integer;
    FintGetFullNameThreadCount: Integer;
    { 创建 Sqlite3 数据库 }
    procedure CreateSqlite3DB;
    { 开始搜索整个磁盘文件 }
    procedure SearchDrivesFiles;
    { 开始绘制数据列表 }
    procedure DrawDataItem;
  protected
    { 单个磁盘文件搜索结束 }
    procedure SearchDriveFinished(var msg: TMessage); message WM_SEARCHDRIVEFINISHED;
    { 获取文件全路径结束 }
    procedure GetFileFullFinished(var msg: TMessage); message WM_GETFILEFULLFINISHED;
  end;

procedure db_ShowDllForm_Plugins(var frm: TFormClass; var strParentModuleName, strModuleName: PAnsiChar); stdcall;

implementation

{$R *.dfm}

procedure db_ShowDllForm_Plugins(var frm: TFormClass; var strParentModuleName, strModuleName: PAnsiChar); stdcall;
begin
  frm                     := TfrmNTFSFiles;
  strParentModuleName     := '系统管理';
  strModuleName           := 'NTFS 文件搜索';
  Application.Handle      := GetMainFormApplication.Handle;
  Application.Icon.Handle := GetMainFormApplication.Icon.Handle;
end;

{ 开始绘制数据列表 }
procedure TfrmNTFSFiles.DrawDataItem;
begin
  lvData.Items.Count := FDatabase.ExecuteNoExceptionInt64('select count(*) from NTFS');
end;

procedure TfrmNTFSFiles.tmrGetFileFullNameStopTimer(Sender: TObject);
begin
  if FintGetFullNameThreadCount <> 0 then
    Exit;

  tmrGetFileFullNameStop.Enabled := False;
  // DrawDataItem;
end;

procedure TfrmNTFSFiles.tmrSearchStartTimer(Sender: TObject);
begin
  tmrSearchStart.Enabled := False;

  { 开始搜索整个磁盘文件 }
  SearchDrivesFiles;
end;

procedure TfrmNTFSFiles.FormDestroy(Sender: TObject);
var
  strDBFileName: String;
begin
  if FDatabase <> nil then
  begin
    FDatabase.DBClose;
    FDatabase.Free;
    FDatabase := nil;
  end;

  if FlstAllDrives <> nil then
    FlstAllDrives.Free;

  strDBFileName := TPath.GetTempPath + 'ntfs.db';
  DeleteFile(strDBFileName);
end;

{ 创建 Sqlite3 数据库 }
procedure TfrmNTFSFiles.CreateSqlite3DB;
var
  strDBFileName: String;
  bExistDB     : Boolean;
begin
  strDBFileName := TPath.GetTempPath + 'ntfs.db';
  if FileExists(strDBFileName) then
    bExistDB := not DeleteFile(strDBFileName)
  else
    bExistDB := False;

  FDatabase := TSQLDataBase.Create(strDBFileName);
  FDatabase.Execute(PAnsiChar('PRAGMA synchronous = OFF;'));                                                                                                                                                                              // 关闭写同步，加快写入速度
  if bExistDB then                                                                                                                                                                                                                        // 如果数据库已经存在
    FDatabase.Execute(PAnsiChar(AnsiString('DROP TABLE NTFS;')));                                                                                                                                                                         // 删除表
  FDatabase.Execute(PAnsiChar(AnsiString('CREATE TABLE NTFS ([ID] INTEGER PRIMARY KEY, [Drive] VARCHAR(1), [FileID] INTEGER NULL, [FilePID] INTEGER NULL, [IsDir] INTEGER NULL, [FileName] VARCHAR (255), [FullName] VARCHAR (255));'))); // 创建表结构

  { 开启事务，加快写入速度 }
  FDatabase.TransactionBegin();
end;

{ 开始搜索整个磁盘文件 }
procedure TfrmNTFSFiles.SearchDrivesFiles;
var
  strDrive: String;
  lstDrive: System.Types.TStringDynArray;
  sysFlags: DWORD;
  strNTFS : array [0 .. 255] of Char;
  intLen  : DWORD;
  I       : Integer;
begin
  { 创建 Sqlite3 数据库 }
  CreateSqlite3DB;

  { 初始化成员变量 }
  FintCount                  := 0;
  FintSearchDriveThreadCount := 0;
  FintGetFullNameThreadCount := 0;
  FlstAllDrives              := TStringList.Create;

  { 将所有 NTFS 类型盘符加入到待搜索列表 }
  lstDrive := TDirectory.GetLogicalDrives;
  for strDrive in lstDrive do
  begin
    if not GetVolumeInformation(PChar(strDrive), nil, 0, nil, intLen, sysFlags, strNTFS, 256) then
      Continue;

    if not SameText(strNTFS, 'NTFS') then
      Continue;

    FlstAllDrives.Add(strDrive[1]);
  end;

  if FlstAllDrives.Count = 0 then
    Exit;

  FintSearchDriveThreadCount := FlstAllDrives.Count;
  FintStartTime              := GetTickCount;

  { 多线程搜索所有 NTFS 磁盘所有文件 }
  for I := 0 to FlstAllDrives.Count - 1 do
  begin
    TSearchThread.Create(AnsiChar(FlstAllDrives.Strings[I][1]), Handle, FDatabase.db);
  end;

  { 检查所有搜索线程是否结束 }
  tmrSearchStop.Enabled := True;
end;

{ 检查所有搜索线程是否结束 }
procedure TfrmNTFSFiles.tmrSearchStopTimer(Sender: TObject);
// var
// I       : Integer;
// chrDrive: AnsiChar;
begin
  if FintSearchDriveThreadCount <> 0 then
    Exit;

  { 所有搜索线程执行结束 }
  tmrSearchStop.Enabled := False;
  FDatabase.Commit;
  lblTip.Caption := Format('合计文件(%s)：%d，合计用时：%d秒', [FlstAllDrives.DelimitedText, FintCount, (GetTickCount - FintStartTime) div 1000 - 1]);
  DrawDataItem;

  { 获取磁盘文件的全路径文件名称 }
  // for I                          := 0 to FlstAllDrives.Count - 1 do
  // begin
  // chrDrive := AnsiChar(FlstAllDrives.Strings[I][1]);
  // TGetFileFullNameThread.Create(chrDrive, Handle, FDatabase);
  // end;
  // FintGetFullNameThreadCount     := FlstAllDrives.Count;
  // tmrGetFileFullNameStop.Enabled := True;
end;

{ 获取文件全路径结束 }
procedure TfrmNTFSFiles.GetFileFullFinished(var msg: TMessage);
begin
  Dec(FintGetFullNameThreadCount);
end;

{ 单个磁盘文件搜索结束 }
procedure TfrmNTFSFiles.SearchDriveFinished(var msg: TMessage);
begin
  Dec(FintSearchDriveThreadCount);

  FintCount      := FintCount + msg.WParam;
  lblTip.Caption := string(PChar(msg.LParam));
  lblTip.Left    := (lblTip.Parent.Width - lblTip.Width) div 2;
end;

procedure TfrmNTFSFiles.FormResize(Sender: TObject);
begin
  lblTip.Left := (lblTip.Parent.Width - lblTip.Width) div 2;
end;

procedure TfrmNTFSFiles.lvDataData(Sender: TObject; Item: TListItem);
const
  c_Fields: array [0 .. 3] of string = ('Drive', 'FileID', 'FilePID', 'FileName');
var
  I       : Integer;
  strSQL  : String;
  strValue: String;
  jsn     : TJSONArray;
begin
  if Application.Terminated then
    Exit;

  strSQL   := 'select Drive, FileID, FilePID, FileName from NTFS where RowID=' + IntToStr(Item.Index + 1);
  strValue := UTF8ToString(FDatabase.ExecuteJSON(RawUTF8(strSQL), True));
  if System.SysUtils.Trim(strValue) = '' then
    Exit;

  jsn := TJSONObject.ParseJSONValue(TEncoding.UTF8.GetBytes(strValue), 0) as TJSONArray;
  if (jsn <> nil) and (jsn.Count > 0) then
  begin
    Item.Caption := Format('%.10u', [Item.Index + 1]);
    for I        := 1 to lvData.Columns.Count - 1 do
    begin
      Item.SubItems.Add(jsn.Items[0].GetValue<String>(c_Fields[I - 1]));
    end;
  end;
end;

end.
