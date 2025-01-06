unit UAIModel;

interface

uses
  System.Generics.Collections, System.SysUtils, System.Math, UAITypes,
  System.JSON;

type
  TAIModel = class
  private
    FInputLength : Integer;
    FTrained : Boolean;
  public
    FNormalizationRange : TNormalizationRange;
    property Trained : Boolean read FTrained write FTrained;
    property InputLength : Integer read FInputLength write FInputLength;
    procedure ValidateAndNormalizeInput(aInput: TAISampleAtr);
    function NormRangeToJSON : TJSONObject;
    procedure JSONToNormRange(aJson : TJSONObject);
  end;

  TClassificationModel = class(TAIModel)
  public
    FDataset : TAIDatasetClassification;
    procedure PopulateInputLenght;
    procedure ClearDataset;
  end;

  TRegressionModel = class(TAIModel)
  public
    FDataset : TAIDatasetRegression;
    procedure PopulateInputLenght;
    procedure ClearDataset;
  end;

  TRecommendationModel = class(TAIModel)
  public
    FDataset : TAIDatasetRecommendation;
    procedure PopulateInputLenght;
    procedure ClearDataset;
  end;

implementation

uses
  UAuxGlobal, UError;

function TAIModel.NormRangeToJSON: TJSONObject;
var
  MinValuesArray, MaxValuesArray: TJSONArray;
  Value: Double;
begin
  Result := TJSONObject.Create;
  try
    MinValuesArray := TJSONArray.Create;
    for Value in FNormalizationRange.MinValues do begin
      MinValuesArray.Add(Value);
    end;
    Result.AddPair('MinValues', MinValuesArray);

    MaxValuesArray := TJSONArray.Create;
    for Value in FNormalizationRange.MaxValues do begin
      MaxValuesArray.Add(Value);
    end;
    Result.AddPair('MaxValues', MaxValuesArray);
  except
    Result.Free;
    raise;
  end;
end;

procedure TAIModel.JSONToNormRange(aJson : TJSONObject);
var
  MinValuesArray, MaxValuesArray: TJSONArray;
  i: Integer;
begin
  if not Assigned(aJson) then
    raise Exception.Create('Invalid JSON object.');

  MinValuesArray := aJson.GetValue('MinValues') as TJSONArray;
  if Assigned(MinValuesArray) then
  begin
    SetLength(FNormalizationRange.MinValues, MinValuesArray.Count);
    for i := 0 to MinValuesArray.Count - 1 do
      FNormalizationRange.MinValues[i] := MinValuesArray.Items[i].AsType<Double>;
  end
  else
    raise Exception.Create('Missing or invalid "MinValues".');

  MaxValuesArray := aJson.GetValue('MaxValues') as TJSONArray;
  if Assigned(MaxValuesArray) then
  begin
    SetLength(FNormalizationRange.MaxValues, MaxValuesArray.Count);
    for i := 0 to MaxValuesArray.Count - 1 do
      FNormalizationRange.MaxValues[i] := MaxValuesArray.Items[i].AsType<Double>;
  end
  else
    raise Exception.Create('Missing or invalid "MaxValues".');

  InputLength := MaxValuesArray.Count;
end;

procedure TAIModel.ValidateAndNormalizeInput(aInput: TAISampleAtr);
var
  vTempArray : TAISamplesAtr;
begin
  if (not FTrained) or (Length(FNormalizationRange.MinValues) = 0) then begin
    raise Exception.Create(ERROR_MODEL_NOT_TRAINED);
  end;

  if (Length(aInput) <> Length(FNormalizationRange.MinValues)) then begin
    raise Exception.Create(ERROR_INPUT_SIZE_DIFFERENT);
  end;

  vTempArray := [aInput];
  NormalizeSamples(vTempArray, FNormalizationRange);
end;

{ TClassificationModel }

procedure TClassificationModel.ClearDataset;
begin
  SetLength(FDataset, 0);
end;

procedure TRegressionModel.ClearDataset;
begin
  SetLength(FDataset, 0);
end;

procedure TRecommendationModel.ClearDataset;
begin
  SetLength(FDataset, 0);
end;

procedure TClassificationModel.PopulateInputLenght;
begin
  if Length(FDataset) > 0 then begin
    InputLength := Length(FDataset[0].Key);
  end else begin
    InputLength := 0;
  end;
end;

{ TRegressionModel }

procedure TRegressionModel.PopulateInputLenght;
begin
  if Length(FDataset) > 0 then begin
    InputLength := Length(FDataset[0].Key);
  end else begin
    InputLength := 0;
  end;
end;

{ TRecommendationModel }

procedure TRecommendationModel.PopulateInputLenght;
begin
  if Length(FDataset) > 0 then begin
    InputLength := Length(FDataset[0]);
  end else begin
    InputLength := 0;
  end;
end;

end.
