program DelphAIExamples;

uses
  Vcl.Forms,
  UFExamples in 'UFExamples.pas' {FDelphAIExamples};

{$R *.res}

begin
  Application.Initialize;
  Application.MainFormOnTaskbar := True;
  Application.CreateForm(TFDelphAIExamples, FDelphAIExamples);
  Application.Run;
end.
