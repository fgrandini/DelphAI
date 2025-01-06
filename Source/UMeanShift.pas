unit UMeanShift;

interface

uses
  System.SysUtils, System.Math, System.Generics.Collections, Data.DB, UAIModel;

type
  TAISampleAtr = TArray<Double>;
  TAIDatasetClustering = TArray<TAISampleAtr>;

    function MeanShift(aData : TAIDatasetClustering; aBandwidth, aEpsilon : Double; aMaxIterations: Integer = 300): TArray<Integer>; overload;
    function MeanShift(aData : String; aBandwidth, aEpsilon : Double; aMaxIterations: Integer = 300; aHaveHeader : Boolean = True): TArray<Integer>; overload;
    function MeanShift(aData : TDataSet; aBandwidth, aEpsilon : Double; aMaxIterations: Integer = 300): TArray<Integer>; overload;

implementation

uses
  UAITypes, UAuxGlobal;

function Distance(const A, B: TAISampleAtr): Double;
var
  i: Integer;
  Sum: Double;
begin
  Sum := 0.0;
  for i := Low(A) to High(A) do
    Sum := Sum + Sqr(A[i] - B[i]);
  Result := Sqrt(Sum);
end;

function GaussianKernel(Distance, aBandwidth: Double): Double;
begin
  Result := Exp(-0.5 * Sqr(Distance / aBandwidth));
end;

function ShiftPoint(const Point: TAISampleAtr; const aData: TAIDatasetClustering; aBandwidth: Double): TAISampleAtr;
var
  i, j: Integer;
  WeightSum, KernelVal: Double;
  ShiftedPoint: TAISampleAtr;
begin
  SetLength(ShiftedPoint, Length(Point));
  WeightSum := 0.0;

  for i := 0 to High(aData) do
  begin
    KernelVal := GaussianKernel(Distance(Point, aData[i]), aBandwidth);
    WeightSum := WeightSum + KernelVal;

    for j := Low(Point) to High(Point) do
      ShiftedPoint[j] := ShiftedPoint[j] + (aData[i][j] * KernelVal);
  end;

  for j := Low(Point) to High(Point) do
    ShiftedPoint[j] := ShiftedPoint[j] / WeightSum;

  Result := ShiftedPoint;
end;

function Converged(const OldPoint, NewPoint: TAISampleAtr; Epsilon: Double): Boolean;
var
  i: Integer;
begin
  for i := Low(OldPoint) to High(OldPoint) do
  begin
    if Abs(OldPoint[i] - NewPoint[i]) > Epsilon then
      Exit(False);
  end;
  Result := True;
end;

function AllPointsConverged(const ConvergedList: TArray<Boolean>): Boolean;
var
  i: Integer;
begin
  Result := True;
  for i := Low(ConvergedList) to High(ConvergedList) do
  begin
    if not ConvergedList[i] then
    begin
      Result := False;
      Exit;
    end;
  end;
end;

function MeanShift(aData : String; aBandwidth, aEpsilon : Double; aMaxIterations: Integer = 300; aHaveHeader : Boolean = True): TArray<Integer>; overload;
var
  vDataSet : TAIDatasetClustering;
  vNormRange : TNormalizationRange;
begin
  LoadDataset(aData, vDataSet, vNormRange, aHaveHeader);
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
  i, j, Iteration, ClusterIdx: Integer;
  ShiftedPoints: TAIDatasetClustering;
  Labels: TArray<Integer>;
  ConvergedList: TArray<Boolean>;
begin
  if Length(aData) = 0 then begin
    raise Exception.Create('Dataset is empty.');
  end;
  SetLength(ShiftedPoints, Length(aData));
  SetLength(Labels, Length(aData));
  SetLength(ConvergedList, Length(aData));

  FillChar(Labels[0], Length(Labels) * SizeOf(Integer), -1);

  for i := 0 to High(aData) do
    ShiftedPoints[i] := Copy(aData[i]);

  for Iteration := 0 to aMaxIterations - 1 do begin
    for i := 0 to High(aData) do begin
      if not ConvergedList[i] then begin
        ShiftedPoints[i] := ShiftPoint(ShiftedPoints[i], aData, aBandwidth);

        if Converged(aData[i], ShiftedPoints[i], aEpsilon) then begin
          ConvergedList[i] := True;
        end;
      end;
    end;

    if AllPointsConverged(ConvergedList) then begin
      Break;
    end;
  end;

  ClusterIdx := 0;
  for i := 0 to High(aData) do begin
    if Labels[i] = -1 then begin
      Inc(ClusterIdx);
      for j := i to High(aData) do begin
        if Distance(ShiftedPoints[i], ShiftedPoints[j]) < aBandwidth then begin
          Labels[j] := ClusterIdx;
        end;
      end;
    end;
  end;

  Result := Labels;
end;

end.

