unit uThreadGetFileFullName;
{
  ��ȡ�ļ�ȫ·���߳�
  dbyoung@sina.com
  2020-10-02
}

interface

uses
  Winapi.Windows, System.SysUtils, System.Classes, SynCommons, SynSQLite3, db.uCommon;

type
  TGetFileFullNameThread = class(TThread)
  private
    FchrDrive      : AnsiChar;
    FMainFormHandle: THandle;
    FSQLDataBase   : TSQLDataBase;
    { �Ȼ�ȡĿ¼��ȫ·������ }
    procedure GetDriverFullFileName_Dir(const chrDrive: AnsiChar);
    { �ٻ�ȡ�ļ���ȫ·������ }
    procedure GetDriverFullFileName_File(const chrDrive: AnsiChar);
  protected
    procedure Execute; override;
  public
    constructor Create(const chrDrive: AnsiChar; const MainFormHandle: THandle; SqlDataBase: TSQLDataBase); overload;
  end;

implementation

{ TGetFileFullThread }

constructor TGetFileFullNameThread.Create(const chrDrive: AnsiChar; const MainFormHandle: THandle; SqlDataBase: TSQLDataBase);
begin
  inherited Create(False);
  FreeOnTerminate := True;
  FchrDrive       := chrDrive;
  FMainFormHandle := MainFormHandle;
  FSQLDataBase    := SqlDataBase;
end;

procedure TGetFileFullNameThread.Execute;
begin
  { �Ȼ�ȡĿ¼��ȫ·������ }
  GetDriverFullFileName_Dir(FchrDrive);

  { �ٻ�ȡ�ļ���ȫ·������ }
  GetDriverFullFileName_File(FchrDrive);

  SendMessage(FMainFormHandle, WM_GETFILEFULLFINISHED, 0, 0);
end;

procedure TGetFileFullNameThread.GetDriverFullFileName_Dir(const chrDrive: AnsiChar);
const
  c_strSQL =                                                                                                                                                                         //
    ' with recursive ' +                                                                                                                                                             //
    ' TempTable(ID, FILEID, FILEPID, FILENAME) AS ' +                                                                                                                         //
    ' ( ' +                                                                                                                                                                          //
    ' select ID, FileID, FilePID, FileName from NTFS where FILEPID = 0x5000000000005 and Drive=%s and IsDir=1 ' +                                                             //
    ' union all ' +                                                                                                                                                                  //
    ' select a.ID, a.FILEID, a.FILEPID, b.FileName || ''\'' || a.FILENAME from NTFS  a inner join TempTable b on (a.FILEPID = b.FILEID) where a.Drive=%s and a.IsDir=1 ' + //
    ' ) ' +                                                                                                                                                                          //
    ' update NTFS set FullName=(select %s || FILENAME from TempTable where TempTable.ID=NTFS.ID) where NTFS.Drive=%s and NTFS.IsDir=1;';
begin
  FSQLDataBase.ExecuteNoException(RawUTF8(Format(c_strSQL, [QuotedStr(chrDrive), QuotedStr(chrDrive), QuotedStr(chrDrive + ':\'), QuotedStr(chrDrive), QuotedStr(chrDrive)])));
end;

procedure TGetFileFullNameThread.GetDriverFullFileName_File(const chrDrive: AnsiChar);
begin

end;

end.
