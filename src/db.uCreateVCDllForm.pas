unit db.uCreateVCDllForm;
{
  创建 VC Dialog DLL / VC MFC DLL 窗体
}

interface

uses Winapi.Windows, Winapi.Messages, System.SysUtils, System.Classes, Vcl.Forms, Vcl.ComCtrls, HookUtils, db.uCommon;

{ 运行 VC DLL 窗体 }
procedure PBoxRun_VCDll(const strVCDllFileName, strFileValue: String; tsDll: TTabSheet; OnVCDllFormDestroyCallback: TNotifyEvent);

{ 非用户触发，程序调用强制关闭 VC DLL 窗体 }
procedure FreeVCDllForm(const bExit: Boolean = False);

implementation

var
  FOld_CreateWindowExW       : function(dwExStyle: DWORD; lpClassName: LPCWSTR; lpWindowName: LPCWSTR; dwStyle: DWORD; X, Y, nWidth, nHeight: Integer; hWndParent: hWnd; hMenu: hMenu; hins: HINST; lpp: Pointer): hWnd; stdcall;
  FstrVCDllClassName         : String = '';
  FstrVCDllWindowName        : String = '';
  FhVCDLLForm                : THandle;
  FTabDllForm                : TTabSheet;
  FOldWndProc                : Pointer = nil;
  FstrCreateDllFileName      : String  = '';
  FhVCDllModule              : HMODULE;
  FLangStyle                 : TLangStyle;
  FbExit                     : Boolean = False;
  FOnVCDllFormDestroyCallback: TNotifyEvent;

procedure DLog(const strLog: String);
begin
  OutputDebugString(PChar(Format('%s  %s', [FormatDateTime('YYYY-MM-DD hh:mm:ss', Now), strLog])));
end;

{ 解决 Dll 中，当 Dll 窗体获取焦点，主窗体变成非激活状态 }
function NewDllFormProc(hWnd: THandle; msg: UINT; wParam: Cardinal; lParam: Cardinal): Integer; stdcall;
begin
  { 如果子窗体获取焦点时，激活主窗体 }
  if msg = WM_ACTIVATE then
  begin
    if Application.MainForm <> nil then
    begin
      SendMessage(Application.MainForm.Handle, WM_NCACTIVATE, Integer(True), 0);
    end;
  end;

  { 禁止窗体移动 }
  if msg = WM_SYSCOMMAND then
  begin
    if wParam = SC_MOVE + 2 then
    begin
      wParam := 0;
    end;
  end;

  { 调用原来的回调过程 }
  Result := CallWindowProc(FOldWndProc, hWnd, msg, wParam, lParam);
end;

{ 创建 VC DLL 窗体 }
procedure CreateVCDllForm;
begin
  FTabDllForm.PageControl.ActivePage := FTabDllForm;                                                                          //
  Winapi.Windows.SetParent(FhVCDLLForm, FTabDllForm.Handle);                                                                  // 设置父窗体为 TabSheet
  RemoveMenu(GetSystemMenu(FhVCDLLForm, False), 0, MF_BYPOSITION);                                                            // 删除移动菜单
  RemoveMenu(GetSystemMenu(FhVCDLLForm, False), 0, MF_BYPOSITION);                                                            // 删除移动菜单
  RemoveMenu(GetSystemMenu(FhVCDLLForm, False), 0, MF_BYPOSITION);                                                            // 删除移动菜单
  RemoveMenu(GetSystemMenu(FhVCDLLForm, False), 0, MF_BYPOSITION);                                                            // 删除移动菜单
  RemoveMenu(GetSystemMenu(FhVCDLLForm, False), 0, MF_BYPOSITION);                                                            // 删除移动菜单
  RemoveMenu(GetSystemMenu(FhVCDLLForm, False), 0, MF_BYPOSITION);                                                            // 删除移动菜单
  RemoveCaption(FhVCDLLForm);                                                                                                 // 去除标题栏
  SetWindowPos(FhVCDLLForm, FTabDllForm.Handle, 0, 0, FTabDllForm.Width, FTabDllForm.Height, SWP_NOZORDER OR SWP_NOACTIVATE); // 最大化 DLL 子窗体
  FOldWndProc := Pointer(GetWindowlong(FhVCDLLForm, GWL_WNDPROC));                                                            // 解决 DLL 窗体获取焦点时，主窗体丢失焦点的问题
  SetWindowLong(FhVCDLLForm, GWL_WNDPROC, LongInt(@NewDllFormProc));                                                          // 拦截 DLL 窗体消息
  PostMessage(Application.MainForm.Handle, WM_NCACTIVATE, 1, 0);                                                              // 激活主窗体
  UnHook(@FOld_CreateWindowExW);                                                                                              // UNHOOK
  FOld_CreateWindowExW := nil;                                                                                                // UNHOOK
end;

function HookCreateWindowExW(dwExStyle: DWORD; lpClassName: LPCWSTR; lpWindowName: LPCWSTR; dwStyle: DWORD; X, Y, nWidth, nHeight: Integer; hWndParent: hWnd; hMenu: hMenu; hins: HINST; lpp: Pointer): hWnd; stdcall;
begin
  { 是指定的 VC 窗体 }
  if (lpClassName <> nil) and (lpWindowName <> nil) and (SameText(lpClassName, FstrVCDllClassName)) and (SameText(lpWindowName, FstrVCDllWindowName)) then
  begin
    if (FLangStyle = lsVCDLGDll) or (FLangStyle = lsQTDll) then
    begin
      { 创建 VC DLG DLL 窗体 }
      Result      := FOld_CreateWindowExW($00010101, lpClassName, lpWindowName, $96C80000, 0, 0, 0, 0, hWndParent, hMenu, hins, lpp); //
      FhVCDLLForm := Result;
      CreateVCDllForm;
    end
    else
    begin
      { 创建 VC MFC DLL 窗体。因为 MFC 窗体是在线程中创建的，所以这里不能加入任何 DELPHI 的代码，阻碍 VC 线程的执行 }
      Result      := FOld_CreateWindowExW(dwExStyle, lpClassName, lpWindowName, dwStyle xor WS_MINIMIZEBOX xor WS_MAXIMIZEBOX, X, Y, nWidth, nHeight, hWndParent, hMenu, hins, lpp);
      FhVCDLLForm := Result;
    end;
  end
  else
  begin
    Result := FOld_CreateWindowExW(dwExStyle, lpClassName, lpWindowName, dwStyle, X, Y, nWidth, nHeight, hWndParent, hMenu, hins, lpp);
  end;
end;

var
  FNewstrVCDllFileName          : String;
  FNewstrFileValue              : String;
  FNewtsDll                     : TTabSheet;
  FNewOnVCDllFormDestroyCallback: TNotifyEvent;

procedure FindVCDLGDLLFormEnd(hWnd: hWnd; uMsg, idEvent: UINT; dwTime: DWORD); stdcall;
begin
  if FhVCDllModule = 0 then
  begin
    KillTimer(Application.MainForm.Handle, $4000);
    PBoxRun_VCDll(FNewstrVCDllFileName, FNewstrFileValue, FNewtsDll, FNewOnVCDllFormDestroyCallback);
  end;
end;

{ 全局变量复位 }
procedure FreeAndReset;
begin
  FreeLibrary(FhVCDllModule);
  FhVCDllModule         := 0;
  FhVCDLLForm           := 0;
  FstrVCDllClassName    := '';
  FstrVCDllWindowName   := '';
  FstrCreateDllFileName := '';
  FOnVCDllFormDestroyCallback(nil);

  { 是否退出程序 }
  if FbExit then
  begin
    Application.MainForm.Close;
  end;
end;

{ 定时查看，MFC DLL 窗体是否被关闭 }
procedure FindMFCDllFormClose(hWnd: hWnd; uMsg, idEvent: UINT; dwTime: DWORD); stdcall;
begin
  if not IsWindowVisible(FhVCDLLForm) then
  begin
    KillTimer(Application.MainForm.Handle, $2000);
    FreeAndReset;
  end;
end;

{ 查找 EXE 的主窗体是否成功创建 }
procedure FindMFCDllFormCreate(hWnd: hWnd; uMsg, idEvent: UINT; dwTime: DWORD); stdcall;
begin
  if FhVCDLLForm = 0 then
    Exit;

  KillTimer(Application.MainForm.Handle, $1000);                            // 销毁定时器
  CreateVCDllForm;                                                          // 创建 VC DLL 窗体
  ShowWindow(FhVCDLLForm, SW_SHOW);                                         // 显示 MFC DLL 窗体
  SetTimer(Application.MainForm.Handle, $2000, 1000, @FindMFCDllFormClose); // 定时查看，MFC DLL 窗体是否被关闭
end;

{ 运行 VC DLL 窗体 }
procedure PBoxRun_VCDll(const strVCDllFileName, strFileValue: String; tsDll: TTabSheet; OnVCDllFormDestroyCallback: TNotifyEvent);
var
  hDll                             : HMODULE;
  ShowVCDllForm                    : Tdb_ShowDllForm_Plugins_VCForm;
  strParamModuleName, strModuleName: PAnsiChar;
  strClassName, strWindowName      : PAnsiChar;
begin
  { 等待先前的 VC Dialog DLL Form 模态窗体销毁完成，才能进行新的 DLL 创建 }
  if FhVCDllModule <> 0 then
  begin
    FNewstrVCDllFileName           := strVCDllFileName;
    FNewstrFileValue               := strFileValue;
    FNewtsDll                      := tsDll;
    FNewOnVCDllFormDestroyCallback := OnVCDllFormDestroyCallback;
    SetTimer(Application.MainForm.Handle, $4000, 200, @FindVCDLGDLLFormEnd);
    Exit;
  end;

  if CompareText(FstrCreateDllFileName, strVCDllFileName) = 0 then
    Exit;

  FTabDllForm                 := tsDll;
  FstrCreateDllFileName       := strVCDllFileName;
  FbExit                      := False;
  FOnVCDllFormDestroyCallback := OnVCDllFormDestroyCallback;

  { 只获取参数，不调用显示窗体。下 HOOK，HOOK 指定窗体 }
  hDll := LoadLibrary(PChar(strVCDllFileName));
  try
    ShowVCDllForm := GetProcAddress(hDll, c_strDllExportFuncName);
    ShowVCDllForm(FLangStyle, strParamModuleName, strModuleName, strClassName, strWindowName, False);
    FstrVCDllClassName  := String(strClassName);
    FstrVCDllWindowName := String(strWindowName);
    HookProcInModule(user32, 'CreateWindowExW', @HookCreateWindowExW, @FOld_CreateWindowExW);
  finally
    FreeLibrary(hDll);
  end;

  { 加载 VC Dialog Dll 模态窗体；关闭即释放 }
  if (FLangStyle = lsVCDLGDll) or (FLangStyle = lsQTDll) then
  begin
    FhVCDllModule := LoadLibrary(PChar(strVCDllFileName));
    ShowVCDllForm := GetProcAddress(FhVCDllModule, c_strDllExportFuncName);
    ShowVCDllForm(FLangStyle, strParamModuleName, strModuleName, strClassName, strWindowName, True);

    { 全局变量复位 }
    FreeAndReset;
  end
  else if FLangStyle = lsVCMFCDll then
  begin
    { 加载 VC MFC Dll 非模态窗体 }
    FhVCDLLForm   := 0;
    FhVCDllModule := LoadLibrary(PChar(strVCDllFileName));
    ShowVCDllForm := GetProcAddress(FhVCDllModule, c_strDllExportFuncName);
    ShowVCDllForm(FLangStyle, strParamModuleName, strModuleName, strClassName, strWindowName, True);
    SetTimer(Application.MainForm.Handle, $1000, 200, @FindMFCDllFormCreate);
  end;
end;

{ 非用户触发，程序调用强制关闭 VC DLL 窗体 }
procedure FreeVCDllForm(const bExit: Boolean = False);
begin
  if FhVCDLLForm = 0 then
    Exit;

  FbExit := bExit;

  { 发送关闭窗体命令 }
  PostMessage(FhVCDLLForm, WM_SYSCOMMAND, SC_CLOSE, 0);
end;

end.
