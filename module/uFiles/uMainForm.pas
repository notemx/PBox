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
    { ���� Sqlite3 ���ݿ� }
    procedure CreateSqlite3DB;
    { ��ʼ�������������ļ� }
    procedure SearchDrivesFiles;
    { ��ʼ���������б� }
    procedure DrawDataItem;
  protected
    { ���������ļ��������� }
    procedure SearchDriveFinished(var msg: TMessage); message WM_SEARCHDRIVEFINISHED;
    { ��ȡ�ļ�ȫ·������ }
    procedure GetFileFullFinished(var msg: TMessage); message WM_GETFILEFULLFINISHED;
  end;

procedure db_ShowDllForm_Plugins(var frm: TFormClass; var strParentModuleName, strModuleName: PAnsiChar); stdcall;

implementation

{$R *.dfm}

procedure db_ShowDllForm_Plugins(var frm: TFormClass; var strParentModuleName, strModuleName: PAnsiChar); stdcall;
begin
  frm                     := TfrmNTFSFiles;
  strParentModuleName     := 'ϵͳ����';
  strModuleName           := 'NTFS �ļ�����';
  Application.Handle      := GetMainFormApplication.Handle;
  Application.Icon.Handle := GetMainFormApplication.Icon.Handle;
end;

{ ��ʼ���������б� }
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

  { ��ʼ�������������ļ� }
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

{ ���� Sqlite3 ���ݿ� }
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
  FDatabase.Execute(PAnsiChar('PRAGMA synchronous = OFF;'));                                                                                                                                                    // �ر�дͬ�����ӿ�д���ٶ�
  if bExistDB then                                                                                                                                                                                              // ������ݿ��Ѿ�����
    FDatabase.Execute(PAnsiChar(AnsiString('DROP TABLE NTFS;')));                                                                                                                                               // ɾ����
  FDatabase.Execute(PAnsiChar(AnsiString('CREATE TABLE NTFS ([ID] INTEGER PRIMARY KEY, [Drive] VARCHAR(1), [FileID] INTEGER NULL, [FilePID] INTEGER NULL, [IsDir] INTEGER NULL, [FileName] VARCHAR (255), [FullName] VARCHAR (255));'))); // ������ṹ

  { �������񣬼ӿ�д���ٶ� }
  FDatabase.TransactionBegin();
end;

{ ��ʼ�������������ļ� }
procedure TfrmNTFSFiles.SearchDrivesFiles;
var
  strDrive: String;
  lstDrive: System.Types.TStringDynArray;
  sysFlags: DWORD;
  strNTFS : array [0 .. 255] of Char;
  intLen  : DWORD;
  I       : Integer;
begin
  { ���� Sqlite3 ���ݿ� }
  CreateSqlite3DB;

  { ��ʼ����Ա���� }
  FintCount                  := 0;
  FintSearchDriveThreadCount := 0;
  FintGetFullNameThreadCount := 0;
  FlstAllDrives              := TStringList.Create;

  { ������ NTFS �����̷����뵽�������б� }
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

  { ���߳��������� NTFS ���������ļ� }
  for I := 0 to FlstAllDrives.Count - 1 do
  begin
    TSearchThread.Create(AnsiChar(FlstAllDrives.Strings[I][1]), Handle, FDatabase.db);
  end;

  { ������������߳��Ƿ���� }
  tmrSearchStop.Enabled := True;
end;

{ ������������߳��Ƿ���� }
procedure TfrmNTFSFiles.tmrSearchStopTimer(Sender: TObject);
// var
// I       : Integer;
// chrDrive: AnsiChar;
begin
  if FintSearchDriveThreadCount <> 0 then
    Exit;

  { ���������߳�ִ�н��� }
  tmrSearchStop.Enabled := False;
  FDatabase.Commit;
  lblTip.Caption := Format('�ϼ��ļ�(%s)��%d���ϼ���ʱ��%d��', [FlstAllDrives.DelimitedText, FintCount, (GetTickCount - FintStartTime) div 1000 - 1]);
  DrawDataItem;

  { ��ȡ�����ļ���ȫ·���ļ����� }
  // for I                          := 0 to FlstAllDrives.Count - 1 do
  // begin
  // chrDrive := AnsiChar(FlstAllDrives.Strings[I][1]);
  // TGetFileFullNameThread.Create(chrDrive, Handle, FDatabase);
  // end;
  // FintGetFullNameThreadCount     := FlstAllDrives.Count;
  // tmrGetFileFullNameStop.Enabled := True;
end;

{ ��ȡ�ļ�ȫ·������ }
procedure TfrmNTFSFiles.GetFileFullFinished(var msg: TMessage);
begin
  Dec(FintGetFullNameThreadCount);
end;

{ ���������ļ��������� }
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
