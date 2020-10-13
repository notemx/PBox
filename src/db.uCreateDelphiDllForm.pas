unit db.uCreateDelphiDllForm;
{
  创建 Delphi DLL 窗体
}

interface

uses Winapi.Windows, Winapi.Messages, System.Classes, System.SysUtils, Vcl.Forms, Vcl.Graphics, Vcl.ComCtrls, Vcl.Controls, Data.Win.ADODB, db.uCommon;

{ 运行 DELPHI DLL 窗体 }
procedure PBoxRun_DelphiDll(const strPEFileName, strFileValue: String; tsDllForm: TTabSheet; OnDelphiDllFormClose: TCloseEvent);

{ 非用户触发，程序调用强制关闭 DELPHI DLL 窗体时 }
procedure FreeDelphiDllForm;

implementation

var
  FhDelphiDllModule: HMODULE = 0;
  FhDelphiDllHandle: THandle;
  FstrFileValue    : String;

procedure DLog(const strLog: String);
begin
  OutputDebugString(PChar(Format('%s  %s', [FormatDateTime('YYYY-MM-DD hh:mm:ss', Now), strLog])));
end;

{ DLL 窗体释放完毕，释放资源并变量复位 }
function FreeAndRest: Boolean;
begin
  Result := False;
  if not IsWindowVisible(FhDelphiDllHandle) then
  begin
    KillTimer(Application.MainForm.Handle, $3000);
    FreeLibrary(FhDelphiDllModule);
    FhDelphiDllHandle := 0;
    FstrFileValue     := '';
    Result            := True;
  end;
end;

{ 用户触发，点击了关闭按钮时，需时时检查，Delphi DLL 窗体是否关闭了，如果关闭了，变量复位 }
procedure tmrCheckDelphiFormDllDestory(hWnd: hWnd; uMsg, idEvent: UINT; dwTime: DWORD); stdcall;
begin
  FreeAndRest;
end;

{ 非用户触发，程序调用强制关闭 DELPHI DLL 窗体时 }
procedure FreeDelphiDllForm;
begin
  if FhDelphiDllHandle = 0 then
    Exit;

  { 发送关闭 Delphi DLL 窗体消息 }
  PostMessage(FhDelphiDllHandle, WM_SYSCOMMAND, SC_CLOSE, 0);

  { 等待窗体关闭 }
  while True do
  begin
    Application.ProcessMessages;
    if FreeAndRest then
      Break;
  end;
end;

{ 挂接 ADOCNN }
procedure CheckDllFormDatabase(DllForm: TForm);
var
  I: Integer;
begin
  if not g_ADOCNN.Connected then
    Exit;

  for I := 0 to DllForm.ComponentCount - 1 do
  begin
    if DllForm.Components[I] is TADOQuery then
    begin
      TADOQuery(DllForm.Components[I]).Connection := g_ADOCNN;
    end;
  end;
end;

{ 运行 DELPHI DLL 窗体 }
procedure PBoxRun_DelphiDll(const strPEFileName, strFileValue: String; tsDllForm: TTabSheet; OnDelphiDllFormClose: TCloseEvent);
var
  ShowDllForm       : Tdb_ShowDllForm_Plugins_Delphi;
  frm               : TFormClass;
  strParamModuleName: PAnsiChar;
  strModuleName     : PAnsiChar;
  frmDelphiDll      : TForm;
begin
  if SameText(FstrFileValue, strFileValue) then
    Exit;

  FstrFileValue     := strFileValue;
  FhDelphiDllModule := LoadLibrary(PChar(strPEFileName));
  ShowDllForm       := GetProcAddress(FhDelphiDllModule, c_strDllExportFuncName);
  ShowDllForm(frm, strParamModuleName, strModuleName);
  frmDelphiDll             := frm.Create(nil);
  frmDelphiDll.BorderIcons := [biSystemMenu];
  frmDelphiDll.Position    := poDesigned;
  frmDelphiDll.BorderStyle := bsSingle;
  frmDelphiDll.Color       := clWhite;
  frmDelphiDll.Anchors     := [akLeft, akTop, akRight, akBottom];
  FhDelphiDllHandle        := frmDelphiDll.Handle;                                                                              // 保存下窗体句柄
  frmDelphiDll.OnClose     := OnDelphiDllFormClose;                                                                             // Dll 窗体销毁时，回调主窗体事件；因为 OnClose 事件被 PBox 接管，所以 DLL 中，资源释放应放到 OnDestory 事件中；
  CheckDllFormDatabase(frmDelphiDll);                                                                                           // 数据库检查
  RemoveMenu(GetSystemMenu(frmDelphiDll.Handle, False), 0, MF_BYPOSITION);                                                      // 删除移动菜单
  RemoveMenu(GetSystemMenu(frmDelphiDll.Handle, False), 0, MF_BYPOSITION);                                                      // 删除大小菜单
  RemoveMenu(GetSystemMenu(frmDelphiDll.Handle, False), 0, MF_BYPOSITION);                                                      // 删除最小化菜单
  RemoveMenu(GetSystemMenu(frmDelphiDll.Handle, False), 0, MF_BYPOSITION);                                                      // 删除最大化菜单
  RemoveMenu(GetSystemMenu(frmDelphiDll.Handle, False), 0, MF_BYPOSITION);                                                      // 删除分割线菜单
  RemoveMenu(GetSystemMenu(frmDelphiDll.Handle, False), 0, MF_BYPOSITION);                                                      // 删除移动菜单
  RemoveCaption(frmDelphiDll.Handle);                                                                                           // 去除标题栏
  SetWindowPos(frmDelphiDll.Handle, tsDllForm.Handle, 0, 0, tsDllForm.Width, tsDllForm.Height, SWP_NOZORDER OR SWP_NOACTIVATE); // 最大化 Dll 子窗体
  Winapi.Windows.SetParent(frmDelphiDll.Handle, tsDllForm.Handle);                                                              // 设置父窗体为 TabSheet
  frmDelphiDll.Show;                                                                                                            // 显示 Dll 子窗体
  tsDllForm.PageControl.ActivePage := tsDllForm;                                                                                // 激活窗口
  SetTimer(Application.MainForm.Handle, $3000, 100, @tmrCheckDelphiFormDllDestory);                                             // 定时检查 Delphi DLL 窗体是否被销毁了
end;

end.
