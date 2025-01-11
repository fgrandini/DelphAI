unit UAIModel;

interface

uses
  System.Generics.Collections,
  System.SysUtils,
  System.Math,
  UAITypes,
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
  UAuxGlobal,
  UError;

function TAIModel.NormRangeToJSON: TJSONObject;
var
  vMinValuesArray, vMaxValuesArray: TJSONArray;
  vValue: Double;
begin
  Result := TJSONObject.Create;
  try
    vMinValuesArray := TJSONArray.Create;
    for vValue in FNormalizationRange.MinValues do begin
      vMinValuesArray.Add(vValue);
    end;
    Result.AddPair('MinValues', vMinValuesArray);

    vMaxValuesArray := TJSONArray.Create;
    for vValue in FNormalizationRange.MaxValues do begin
      vMaxValuesArray.Add(vValue);
    end;
    Result.AddPair('MaxValues', vMaxValuesArray);
  except
    Result.Free;
    raise;
  end;
end;

procedure TAIModel.JSONToNormRange(aJson : TJSONObject);
var
  vMinValuesArray, vMaxValuesArray: TJSONArray;
  i: Integer;
begin
  if not Assigned(aJson) then
    raise Exception.Create('Invalid JSON object.');

  vMinValuesArray := aJson.GetValue('MinValues') as TJSONArray;
  if Assigned(vMinValuesArray) then
  begin
    SetLength(FNormalizationRange.MinValues, vMinValuesArray.Count);
    for i := 0 to vMinValuesArray.Count - 1 do
      FNormalizationRange.MinValues[i] := vMinValuesArray.Items[i].AsType<Double>;
  end
  else
    raise Exception.Create('Missing or invalid "MinValues".');

  vMaxValuesArray := aJson.GetValue('MaxValues') as TJSONArray;
  if Assigned(vMaxValuesArray) then
  begin
    SetLength(FNormalizationRange.MaxValues, vMaxValuesArray.Count);
    for i := 0 to vMaxValuesArray.Count - 1 do
      FNormalizationRange.MaxValues[i] := vMaxValuesArray.Items[i].AsType<Double>;
  end
  else
    raise Exception.Create('Missing or invalid "MaxValues".');

  InputLength := vMaxValuesArray.Count;
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
