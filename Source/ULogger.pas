unit ULogger;

interface

uses
  System.Classes, System.SysUtils, System.SyncObjs;

type
  TLogger = class
  private
    FLogBuffer: TStringList;
    FLogFile: string;
    FLock: TCriticalSection;
    FThread: TThread;
    FTerminateThread: Boolean;
    procedure WriteBufferToFile;
  public
    constructor Create(const ALogFile: string);
    destructor Destroy; override;
    procedure Log(const AMessage: string);
  end;

implementation

uses
  Vcl.Dialogs, System.IOUtils;

constructor TLogger.Create(const ALogFile: string);
begin
  FLogFile := ALogFile;
  if ALogFile = '' then begin
    Exit;
  end;
  FLogBuffer := TStringList.Create;
  FLock := TCriticalSection.Create;
  FTerminateThread := False;

  FThread := TThread.CreateAnonymousThread(
    procedure
    begin
      while not FTerminateThread do
      begin
        Sleep(100); 
        WriteBufferToFile;
      end;
    end);
  FThread.FreeOnTerminate := False;
  FThread.Start;
end;

destructor TLogger.Destroy;
begin
  if FLogFile = '' then begin
    inherited;
    Exit;
  end;
  FTerminateThread := True;
  FThread.WaitFor;
  FThread.Free;
  WriteBufferToFile; 
  FLogBuffer.Free;
  FLock.Free;
  inherited;
end;

procedure TLogger.Log(const AMessage: string);
begin
  if FLogFile = '' then begin
    Exit;
  end;
  FLock.Enter;
  try
    FLogBuffer.Add(FormatDateTime('yyyy-mm-dd hh:nn:ss', Now) + ' - ' + AMessage);
  finally
    FLock.Leave;
  end;
end;

procedure TLogger.WriteBufferToFile;
var
  TempBuffer: TStringList;
begin
  TempBuffer := TStringList.Create;
  try
    FLock.Enter;
    try
      TempBuffer.AddStrings(FLogBuffer);
      FLogBuffer.Clear;
    finally
      FLock.Leave;
    end;

    if TempBuffer.Count > 0 then begin
      TFile.AppendAllText(FLogFile, TempBuffer.Text);
    end;
  finally
    TempBuffer.Free;
  end;
end;

end.

