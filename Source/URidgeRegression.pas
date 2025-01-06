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
    public
      procedure Train(aTrainingData : TAIDatasetRegression; aNormalizationRange : TNormalizationRange); overload;
      procedure Train(aTrainingData : String; aHaveHeader : Boolean = True); overload;
      procedure Train(aTrainingData : TDataSet); overload;
      procedure FromJson(aJson: TJsonObject);
      function ToJson: TJsonObject;
      procedure LoadFromFile(const FileName: string);
      procedure SaveToFile(const FileName: string);
      function Predict(aSample : TAISampleAtr; aInputNormalized : Boolean = False): Double;
      constructor Create(aTrainedFile : String); overload;
      constructor Create(aAlfa : Double); overload;
  end;



implementation

uses
  UAuxGlobal, System.Classes, System.Generics.Collections;

function MatrixTranspose(const A: TAISamplesAtr): TAISamplesAtr;
var
  i, j: Integer;
begin
  SetLength(Result, Length(A[0]), Length(A));
  for i := 0 to High(A) do
    for j := 0 to High(A[0]) do
      Result[j][i] := A[i][j];
end;

function MatrixMultiply(const A, B: TAISamplesAtr): TAISamplesAtr;
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

function MatrixVectorMultiply(const A: TAISamplesAtr; const B: TAISampleAtr): TAISampleAtr;
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

function VectorAdd(const A, B: TAISampleAtr): TAISampleAtr;
var
  i: Integer;
begin
  SetLength(Result, Length(A));
  for i := 0 to High(A) do
    Result[i] := A[i] + B[i];
end;

function IdentityMatrix(Size: Integer): TAISamplesAtr;
var
  i: Integer;
begin
  SetLength(Result, Size, Size);
  for i := 0 to Size - 1 do
    Result[i][i] := 1;
end;

function MatrixInverse(const A: TAISamplesAtr): TAISamplesAtr;
var
  i, j, k, n: Integer;
  temp: Double;
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
    temp := Result[i][i];
    for j := 0 to 2 * n - 1 do
      Result[i][j] := Result[i][j] / temp;

    for j := 0 to n - 1 do
    begin
      if i <> j then
      begin
        temp := Result[j][i];
        for k := 0 to 2 * n - 1 do
          Result[j][k] := Result[j][k] - temp * Result[i][k];
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

function MatrixAdd(const A, B: TAISamplesAtr): TAISamplesAtr;
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
  Xt, XtX, Ident, XtX_AlfaI, XtX_AlfaI_inv: TAISamplesAtr;
  XtY: TAISampleAtr;
  i: Integer;
  X: TAISamplesAtr; Y: TAILabelsRegression;
begin

  SplitLabelAndSampleDataset(FDataset, X, Y);
  Xt := MatrixTranspose(X);

  XtX := MatrixMultiply(Xt, X);

  Ident := IdentityMatrix(Length(XtX));
  for i := 0 to High(Ident) do begin
    Ident[i][i] := Ident[i][i] * FAlfa;
  end;

  XtX_AlfaI := MatrixAdd(XtX, Ident);

  XtX_AlfaI_inv := MatrixInverse(XtX_AlfaI);

  XtY := MatrixVectorMultiply(Xt, Y);

  FCoefs := MatrixVectorMultiply(XtX_AlfaI_inv, XtY);

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
  JsonArray: TJsonArray;
  JsonObj : TJSONObject;
  I: Integer;
begin
  Result := TJSONObject.Create;
  JsonObj := TJSONObject.Create;

  Result.AddPair('NormalizationRange', NormRangeToJSON);
  Result.AddPair('InputLength', InputLength);
  Result.AddPair('Model', JsonObj);

  JsonArray := TJsonArray.Create;
  for I := 0 to Length(FCoefs) - 1 do
    JsonArray.Add(FCoefs[I]);

  JsonObj.AddPair('coefficients', JsonArray);
end;

procedure TRidgeRegression.Train(aTrainingData: TAIDatasetRegression;
  aNormalizationRange: TNormalizationRange);
begin
  FNormalizationRange := aNormalizationRange;
  FDataset := Copy(aTrainingData);
  DoTrain;
end;

procedure TRidgeRegression.Train(aTrainingData: String; aHaveHeader: Boolean);
begin
  LoadDataset(aTrainingData, FDataset, FNormalizationRange, aHaveHeader);
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
  JsonArray: TJsonArray;
  I: Integer;
begin
  InputLength := StrToInt(aJson.FindValue('InputLength').Value);
  JSONToNormRange(aJson.FindValue('NormalizationRange') as TJSONObject);
  aJson := aJson.FindValue('Model') as TJSONObject;

  if aJson.TryGetValue<TJsonArray>('coefficients', JsonArray) then begin
    SetLength(FCoefs, JsonArray.Count);
    for I := 0 to JsonArray.Count - 1 do begin
      FCoefs[I] := JsonArray.Items[I].AsType<Double>;
    end;
  end;

  Trained := True;
end;

procedure TRidgeRegression.SaveToFile(const FileName: string);
var
  Json: TJsonObject;
  JsonString: TStringList;
begin
  Json := ToJson;
  try
    JsonString := TStringList.Create;
    try
      JsonString.Text := Json.ToString;
      JsonString.SaveToFile(FileName);
    finally
      JsonString.Free;
    end;
  finally
    Json.Free;
  end;
end;

procedure TRidgeRegression.LoadFromFile(const FileName: string);
var
  Json: TJsonObject;
  JsonString: TStringList;
begin
  JsonString := TStringList.Create;
  try
    JsonString.LoadFromFile(FileName);

    Json := TJsonObject.ParseJsonValue(JsonString.Text) as TJsonObject;
    try
      FromJson(Json);
    finally
      Json.Free;
    end;
  finally
    JsonString.Free;
  end;
end;






end.
