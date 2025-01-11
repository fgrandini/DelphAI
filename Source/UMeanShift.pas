unit UMeanShift;

interface

uses
  System.SysUtils, System.Math, System.Generics.Collections, Data.DB, UAIModel;

type
  TAISampleAtr = TArray<Double>;
  TAIDatasetClustering = TArray<TAISampleAtr>;

  function MeanShift(aData : TAIDatasetClustering; aBandwidth, aEpsilon : Double; aMaxIterations: Integer = 300): TArray<Integer>; overload;
  function MeanShift(aData : String; aBandwidth, aEpsilon : Double; aMaxIterations: Integer = 300; aHasHeader : Boolean = True): TArray<Integer>; overload;
  function MeanShift(aData : TDataSet; aBandwidth, aEpsilon : Double; aMaxIterations: Integer = 300): TArray<Integer>; overload;

implementation

uses
  UAITypes, UAuxGlobal;

function GaussianKernel(aDistance, aBandwidth: Double): Double;
begin
  Result := Exp(-0.5 * Sqr(aDistance / aBandwidth));
end;

function ShiftPoint(const aPoint: TAISampleAtr; const aData: TAIDatasetClustering; aBandwidth: Double): TAISampleAtr;
var
  i, j: Integer;
  vWeightSum, vKernelVal: Double;
  vShiftedPoint: TAISampleAtr;
begin
  SetLength(vShiftedPoint, Length(aPoint));
  vWeightSum := 0.0;

  for i := 0 to High(aData) do
  begin
    vKernelVal := GaussianKernel(Distance(aPoint, aData[i]), aBandwidth);
    vWeightSum := vWeightSum + vKernelVal;

    for j := Low(aPoint) to High(aPoint) do
      vShiftedPoint[j] := vShiftedPoint[j] + (aData[i][j] * vKernelVal);
  end;

  for j := Low(aPoint) to High(aPoint) do
    vShiftedPoint[j] := vShiftedPoint[j] / vWeightSum;

  Result := vShiftedPoint;
end;

function Converged(const aOldPoint, aNewPoint: TAISampleAtr; aEpsilon: Double): Boolean;
var
  i: Integer;
begin
  for i := Low(aOldPoint) to High(aOldPoint) do
  begin
    if Abs(aOldPoint[i] - aNewPoint[i]) > aEpsilon then
      Exit(False);
  end;
  Result := True;
end;

function AllPointsConverged(const aConvergedList: TArray<Boolean>): Boolean;
var
  i: Integer;
begin
  Result := True;
  for i := Low(aConvergedList) to High(aConvergedList) do
  begin
    if not aConvergedList[i] then
    begin
      Result := False;
      Exit;
    end;
  end;
end;

function MeanShift(aData : String; aBandwidth, aEpsilon : Double; aMaxIterations: Integer = 300; aHasHeader : Boolean = True): TArray<Integer>; overload;
var
  vDataSet : TAIDatasetClustering;
  vNormRange : TNormalizationRange;
begin
  LoadDataset(aData, vDataSet, vNormRange, aHasHeader);
  Result := MeanShift(vDataSet, aBandwidth, aEpsilon, aMaxIterations);
end;

function MeanShift(aData : TDataSet; aBandwidth, aEpsilon : Double; aMaxIterations: Integer = 300): TArray<Integer>; overload;
var
  vDataSet : TAIDatasetClustering;
  vNormRange : TNormalizationRange;
begin
  if aData.RecordCount = 0 then begin
    raise Exception.Create('Dataset is empty.');
  end;

  LoadDataset(aData, vDataSet, vNormRange);

  Result := MeanShift(vDataSet, aBandwidth, aEpsilon, aMaxIterations);
end;

function MeanShift(aData: TAIDatasetClustering; aBandwidth, aEpsilon: Double; aMaxIterations: Integer): TArray<Integer>;
var
  i, j, vIteration, vClusterIdx: Integer;
  vShiftedPoints: TAIDatasetClustering;
  vLabels: TArray<Integer>;
  vConvergedList: TArray<Boolean>;
begin
  if Length(aData) = 0 then begin
    raise Exception.Create('Dataset is empty.');
  end;
  SetLength(vShiftedPoints, Length(aData));
  SetLength(vLabels, Length(aData));
  SetLength(vConvergedList, Length(aData));

  FillChar(vLabels[0], Length(vLabels) * SizeOf(Integer), -1);

  for i := 0 to High(aData) do
    vShiftedPoints[i] := Copy(aData[i]);

  for vIteration := 0 to aMaxIterations - 1 do begin
    for i := 0 to High(aData) do begin
      if not vConvergedList[i] then begin
        vShiftedPoints[i] := ShiftPoint(vShiftedPoints[i], aData, aBandwidth);

        if Converged(aData[i], vShiftedPoints[i], aEpsilon) then begin
          vConvergedList[i] := True;
        end;
      end;
    end;

    if AllPointsConverged(vConvergedList) then begin
      Break;
    end;
  end;

  vClusterIdx := 0;
  for i := 0 to High(aData) do begin
    if vLabels[i] = -1 then begin
      Inc(vClusterIdx);
      for j := i to High(aData) do begin
        if Distance(vShiftedPoints[i], vShiftedPoints[j]) < aBandwidth then begin
          vLabels[j] := vClusterIdx;
        end;
      end;
    end;
  end;

  Result := vLabels;
end;

end.

