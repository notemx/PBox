unit uThreadSearchDrive;
{
  NTFS 文件搜索线程
  dbyoung@sina.com
  2020-10-01
}

interface

uses
  Winapi.Windows, System.SysUtils, System.Classes, SynCommons, SynSQLite3, db.uCommon;

type
  TSearchThread = class(TThread)
  private
    FchrDrive      : AnsiChar;
    FMainFormHandle: THandle;
    FDataBase      : TSQLite3DB;
    FsrInsert      : TSQLRequest;
    { 获取文件信息 }
    procedure GetUSNFileInfo(UsnInfo: PUSN);
  protected
    procedure Execute; override;
  public
    constructor Create(const chrDrive: AnsiChar; const MainFormHandle: THandle; DataBase: TSQLite3DB); overload;
  end;

implementation

{ TSearchThread }

const
  c_strInsertSQL: RawUTF8 = 'INSERT INTO NTFS (ID, Drive, FileID, FilePID, IsDir, FileName) VALUES(NULL,?,?,?,?,?)';

constructor TSearchThread.Create(const chrDrive: AnsiChar; const MainFormHandle: THandle; DataBase: TSQLite3DB);
begin
  inherited Create(False);
  FreeOnTerminate := True;
  FchrDrive       := chrDrive;
  FMainFormHandle := MainFormHandle;
  FDataBase       := DataBase;

  FsrInsert.Prepare(FDataBase, RawUTF8(c_strInsertSQL));
end;

procedure TSearchThread.GetUSNFileInfo(UsnInfo: PUSN);
var
  intFileID  : UInt64;
  intFilePID : UInt64;
  strFileName: String;
  intDir     : Integer;
begin
  intFileID   := UsnInfo^.FileReferenceNumber;
  intFilePID  := UsnInfo^.ParentFileReferenceNumber;
  strFileName := PWideChar(Integer(UsnInfo) + UsnInfo^.FileNameOffset);
  strFileName := Copy(strFileName, 1, UsnInfo^.FileNameLength div 2);
  intDir      := Integer(UsnInfo^.FileAttributes and FILE_ATTRIBUTE_DIRECTORY = FILE_ATTRIBUTE_DIRECTORY);
  FsrInsert.Reset;
  FsrInsert.Bind(1, FchrDrive);
  FsrInsert.Bind(2, intFileID);
  FsrInsert.Bind(3, intFilePID);
  FsrInsert.Bind(4, intDir);
  FsrInsert.Bind(5, RawUTF8(strFileName));
  FsrInsert.Step;
end;

{ 简化的 MOVE 函数，也可以用 MOVE 函数来替代 }
procedure MyMove(const Source; var Dest; Count: NativeInt); assembler;
asm
  FILD    QWORD PTR [EAX]
  FISTP   QWORD PTR [EDX]
end;

procedure TSearchThread.Execute;
var
  cjd         : CREATE_USN_JOURNAL_DATA;
  ujd         : USN_JOURNAL_DATA;
  djd         : DELETE_USN_JOURNAL_DATA;
  dwRet       : DWORD;
  int64Size   : Integer;
  BufferOut   : array [0 .. BUF_LEN - 1] of Char;
  BufferIn    : MFT_ENUM_DATA;
  UsnInfo     : PUSN;
  hRootHandle : THandle;
  intST, intET: Cardinal;
  strTip      : String;
  intCount    : Integer;
begin
  hRootHandle := CreateFile(PChar('\\.\' + FchrDrive + ':'), GENERIC_READ or GENERIC_WRITE, FILE_SHARE_READ or FILE_SHARE_WRITE, nil, OPEN_EXISTING, 0, 0);
  if hRootHandle = ERROR_INVALID_HANDLE then
    Exit;

  intST    := GetTickCount;
  intCount := 0;
  try
    { 初始化USN日志文件 }
    if not DeviceIoControl(hRootHandle, FSCTL_CREATE_USN_JOURNAL, @cjd, Sizeof(cjd), nil, 0, dwRet, nil) then
      Exit;

    { 获取USN日志基本信息 }
    if not DeviceIoControl(hRootHandle, FSCTL_QUERY_USN_JOURNAL, nil, 0, @ujd, Sizeof(ujd), dwRet, nil) then
      Exit;

    { 枚举USN日志文件中的所有记录 }
    int64Size                         := Sizeof(Int64);
    BufferIn.StartFileReferenceNumber := 0;
    BufferIn.LowUsn                   := 0;
    BufferIn.HighUsn                  := ujd.NextUsn;
    while DeviceIoControl(hRootHandle, FSCTL_ENUM_USN_DATA, @BufferIn, Sizeof(BufferIn), @BufferOut, BUF_LEN, dwRet, nil) do
    begin
      { 找到第一个 USN 记录 }
      UsnInfo := PUSN(Integer(@(BufferOut)) + int64Size);
      while dwRet > 60 do
      begin
        { 获取文件信息 }
        GetUSNFileInfo(UsnInfo);
        Inc(intCount);

        { 获取下一个 USN 记录 }
        if UsnInfo.RecordLength > 0 then
          Dec(dwRet, UsnInfo.RecordLength)
        else
          Break;

        UsnInfo := PUSN(Cardinal(UsnInfo) + UsnInfo.RecordLength);
      end;
      Move(BufferOut, BufferIn, int64Size);
    end;

    { 删除USN日志文件信息 }
    djd.UsnJournalID := ujd.UsnJournalID;
    djd.DeleteFlags  := USN_DELETE_FLAG_DELETE;
    DeviceIoControl(hRootHandle, FSCTL_DELETE_USN_JOURNAL, @djd, Sizeof(djd), nil, 0, dwRet, nil);
  finally
    CloseHandle(hRootHandle);
    intET  := GetTickCount;
    strTip := FchrDrive + ':\，文件总数：' + IntToStr(intCount) + '，搜索用时：' + IntToStr((intET - intST) div 1000) + '秒';
    SendMessage(FMainFormHandle, WM_SEARCHDRIVEFINISHED, intCount, Integer(PChar(strTip)));
  end;
end;

end.
