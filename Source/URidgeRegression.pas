unit URidgeRegression;

interface

uses
  System.SysUtils, Math, System.Types, UAITypes, System.JSON, Data.DB, UAIModel;

type
  TAISampleAtr = TArray<Double>;

  TRidgeRegression = class(TRegressionModel)
  private
    FCoefs : TAISampleAtr;
    FAlfa : Double;
    procedure DoTrain;
    function IdentityMatrix(aSize: Integer): TAISamplesAtr;
    function MatrixAdd(const A, B: TAISamplesAtr): TAISamplesAtr;
    function MatrixInverse(const A: TAISamplesAtr): TAISamplesAtr;
    function MatrixMultiply(const A, B: TAISamplesAtr): TAISamplesAtr;
    function MatrixTranspose(const A: TAISamplesAtr): TAISamplesAtr;
    function MatrixVectorMultiply(const A: TAISamplesAtr; const B: TAISampleAtr): TAISampleAtr;
  public
    procedure Train(aTrainingData : TAIDatasetRegression; aNormalizationRange : TNormalizationRange); overload;
    procedure Train(aTrainingData : String; aHasHeader : Boolean = True); overload;
    procedure Train(aTrainingData : TDataSet); overload;
    procedure FromJson(aJson: TJsonObject);
    function ToJson: TJsonObject;
    procedure LoadFromFile(const aFileName: string);
    procedure SaveToFile(const aFileName: string);
    function Predict(aSample : TAISampleAtr; aInputNormalized : Boolean = False): Double;
    constructor Create(aTrainedFile : String); overload;
    constructor Create(aAlfa : Double); overload;
  end;

implementation

uses
  UAuxGlobal, System.Classes, System.Generics.Collections;

function TRidgeRegression.MatrixTranspose(const A: TAISamplesAtr): TAISamplesAtr;
var
  i, j: Integer;
begin
  SetLength(Result, Length(A[0]), Length(A));
  for i := 0 to High(A) do
    for j := 0 to High(A[0]) do
      Result[j][i] := A[i][j];
end;

function TRidgeRegression.MatrixMultiply(const A, B: TAISamplesAtr): TAISamplesAtr;
var
  i, j, k: Integer;
begin
  SetLength(Result, Length(A), Length(B[0]));
  for i := 0 to High(A) do
    for j := 0 to High(B[0]) do
    begin
      Result[i][j] := 0;
      for k := 0 to High(A[0]) do
        Result[i][j] := Result[i][j] + A[i][k] * B[k][j];
    end;
end;

function TRidgeRegression.MatrixVectorMultiply(const A: TAISamplesAtr; const B: TAISampleAtr): TAISampleAtr;
var
  i, j: Integer;
begin
  SetLength(Result, Length(A));
  for i := 0 to High(A) do
  begin
    Result[i] := 0;
    for j := 0 to High(A[0]) do
      Result[i] := Result[i] + A[i][j] * B[j];
  end;
end;

function TRidgeRegression.IdentityMatrix(aSize: Integer): TAISamplesAtr;
var
  i: Integer;
begin
  SetLength(Result, aSize, aSize);
  for i := 0 to aSize - 1 do
    Result[i][i] := 1;
end;

function TRidgeRegression.MatrixInverse(const A: TAISamplesAtr): TAISamplesAtr;
var
  i, j, k, n: Integer;
  vTemp: Double;
begin
  n := Length(A);
  SetLength(Result, n, n * 2);

  for i := 0 to n - 1 do
    for j := 0 to n - 1 do
      Result[i][j] := A[i][j];

  for i := 0 to n - 1 do
    Result[i][n + i] := 1;

  for i := 0 to n - 1 do
  begin
    vTemp := Result[i][i];
    for j := 0 to 2 * n - 1 do
      Result[i][j] := Result[i][j] / vTemp;

    for j := 0 to n - 1 do
    begin
      if i <> j then
      begin
        vTemp := Result[j][i];
        for k := 0 to 2 * n - 1 do
          Result[j][k] := Result[j][k] - vTemp * Result[i][k];
      end;
    end;
  end;

  for i := 0 to n - 1 do
  begin
    for j := 0 to n - 1 do
      Result[i][j] := Result[i][j + n];
    SetLength(Result[i], n);
  end;
end;

function TRidgeRegression.MatrixAdd(const A, B: TAISamplesAtr): TAISamplesAtr;
var
  i, j: Integer;
begin
  SetLength(Result, Length(A), Length(A[0]));
  for i := 0 to High(A) do begin
    for j := 0 to High(A[0]) do begin
      Result[i][j] := A[i][j] + B[i][j];
    end;
  end;
end;

procedure TRidgeRegression.DoTrain;
var
  vXt, vXtX, vIdent, vXtX_AlfaI, vXtX_AlfaI_inv: TAISamplesAtr;
  XtY: TAISampleAtr;
  i: Integer;
  X: TAISamplesAtr; Y: TAILabelsRegression;
begin

  SplitLabelAndSampleDataset(FDataset, X, Y);
  vXt := MatrixTranspose(X);

  vXtX := MatrixMultiply(vXt, X);

  vIdent := IdentityMatrix(Length(vXtX));
  for i := 0 to High(vIdent) do begin
    vIdent[i][i] := vIdent[i][i] * FAlfa;
  end;

  vXtX_AlfaI := MatrixAdd(vXtX, vIdent);

  vXtX_AlfaI_inv := MatrixInverse(vXtX_AlfaI);

  XtY := MatrixVectorMultiply(vXt, Y);

  FCoefs := MatrixVectorMultiply(vXtX_AlfaI_inv, XtY);

  PopulateInputLenght;
  Trained := True;
end;

function TRidgeRegression.Predict(aSample : TAISampleAtr; aInputNormalized : Boolean = False) : Double;
begin
  aSample := Copy(aSample);

  if not aInputNormalized then begin
    ValidateAndNormalizeInput(aSample);
  end;
  Result := MatrixVectorMultiply([aSample], FCoefs)[0];
end;

function TRidgeRegression.ToJson: TJsonObject;
var
  vJsonArray: TJsonArray;
  vJsonObj : TJSONObject;
  I: Integer;
begin
  Result := TJSONObject.Create;
  vJsonObj := TJSONObject.Create;

  Result.AddPair('NormalizationRange', NormRangeToJSON);
  Result.AddPair('InputLength', TJSONNumber.Create(InputLength));
  Result.AddPair('Model', vJsonObj);

  vJsonArray := TJsonArray.Create;
  for I := 0 to Length(FCoefs) - 1 do
    vJsonArray.Add(FCoefs[I]);

  vJsonObj.AddPair('coefficients', vJsonArray);
end;

procedure TRidgeRegression.Train(aTrainingData: TAIDatasetRegression;
  aNormalizationRange: TNormalizationRange);
begin
  FNormalizationRange := aNormalizationRange;
  FDataset := Copy(aTrainingData);
  DoTrain;
end;

procedure TRidgeRegression.Train(aTrainingData: String; aHasHeader: Boolean);
begin
  LoadDataset(aTrainingData, FDataset, FNormalizationRange, aHasHeader);
  if Length(FDataset) = 0 then begin
    raise Exception.Create('Dataset is empty.');
  end;
  DoTrain;
end;

procedure TRidgeRegression.Train(aTrainingData: TDataSet);
begin
  if aTrainingData.RecordCount = 0 then begin
    raise Exception.Create('Dataset is empty.');
  end;
  LoadDataset(aTrainingData, FDataset, FNormalizationRange);
  DoTrain;
end;

constructor TRidgeRegression.Create(aAlfa: Double);
begin
  FAlfa := aAlfa;
end;

constructor TRidgeRegression.Create(aTrainedFile: String);
begin
  LoadFromFile(aTrainedFile);
end;

procedure TRidgeRegression.FromJson(aJson: TJsonObject);
var
  vJsonArray: TJsonArray;
  I: Integer;
begin
  InputLength := StrToInt(aJson.FindValue('InputLength').Value);
  JSONToNormRange(aJson.FindValue('NormalizationRange') as TJSONObject);
  aJson := aJson.FindValue('Model') as TJSONObject;

  if aJson.TryGetValue<TJsonArray>('coefficients', vJsonArray) then begin
    SetLength(FCoefs, vJsonArray.Count);
    for I := 0 to vJsonArray.Count - 1 do begin
      FCoefs[I] := vJsonArray.Items[I].AsType<Double>;
    end;
  end;

  Trained := True;
end;

procedure TRidgeRegression.SaveToFile(const aFileName: string);
var
  vJson: TJsonObject;
  vJsonString: TStringList;
begin
  vJson := ToJson;
  try
    vJsonString := TStringList.Create;
    try
      vJsonString.Text := vJson.ToString;
      vJsonString.SaveToFile(aFileName);
    finally
      vJsonString.Free;
    end;
  finally
    vJson.Free;
  end;
end;

procedure TRidgeRegression.LoadFromFile(const aFileName: string);
var
  vJson: TJsonObject;
  vJsonString: TStringList;
begin
  vJsonString := TStringList.Create;
  try
    vJsonString.LoadFromFile(aFileName);

    vJson := TJsonObject.ParseJsonValue(vJsonString.Text) as TJsonObject;
    try
      FromJson(vJson);
    finally
      vJson.Free;
    end;
  finally
    vJsonString.Free;
  end;
end;

end.
