unit UKMeans;

interface

uses
  UAITypes, UAIModel, Data.DB;

type
  TCentroid = TArray<Double>;
  TCentroids = TArray<TCentroid>;

  function KMeans(aData: TAIDatasetClustering; aK, aMaxIterations, aNumInitializations: Integer): TArray<Integer>; overload;
  function KMeans(aData: String; aK, aMaxIterations, aNumInitializations: Integer; aHasHeader : Boolean = True): TArray<Integer>; overload;
  function KMeans(aData: TDataSet; aK, aMaxIterations, aNumInitializations: Integer): TArray<Integer>; overload;

implementation

uses
  UAuxGlobal, System.Math, System.SysUtils;

function ArraysAreEqual(const A, B: TArray<Integer>): Boolean;
var
  i: Integer;
begin
  if Length(A) <> Length(B) then begin
    Exit(False);
  end;

  for i := 0 to Length(A) - 1 do begin
    if A[i] <> B[i] then begin
      Exit(False);
    end;
  end;

  Result := True;
end;

function InitializeCentroids(const aData: TAIDatasetClustering; aK: Integer): TCentroids;
var
  i, j, vIndex: Integer;
  vCentroids: TCentroids;
begin
  SetLength(vCentroids, aK);
  Randomize;
  for i := 0 to aK - 1 do  begin
    vIndex := Random(Length(aData));
    SetLength(vCentroids[i], Length(aData[vIndex]));
    for j := 0 to Length(aData[vIndex]) - 1 do
      vCentroids[i][j] := aData[vIndex][j];
  end;
  Result := vCentroids;
end;

function InitializeCentroidsPlusPlus(const aData: TAIDatasetClustering; aK: Integer): TCentroids;
var
  vCentroids: TCentroids;
  vDistances: TArray<Double>;
  vSumDistances, vRandomVal, vPartialSum: Double;
  i, j, Index: Integer;
begin
  SetLength(vCentroids, aK);
  Randomize;
  Index := Random(Length(aData));
  SetLength(vCentroids[0], Length(aData[Index]));
  for j := 0 to Length(aData[Index]) - 1 do begin
    vCentroids[0][j] := aData[Index][j];
  end;

  for i := 1 to aK - 1 do begin
    SetLength(vDistances, Length(aData));
    vSumDistances := 0;

    for j := 0 to Length(aData) - 1 do begin
      vDistances[j] := CalculateEuclideanDistance(aData[j], vCentroids[0]);
      for Index := 1 to i - 1 do
        vDistances[j] := Min(vDistances[j], CalculateEuclideanDistance(aData[j], vCentroids[Index]));
      vSumDistances := vSumDistances + vDistances[j];
    end;

    vRandomVal := Random * vSumDistances;
    vPartialSum := 0;
    for j := 0 to Length(aData) - 1 do begin
      vPartialSum := vPartialSum + vDistances[j];
      if vPartialSum >= vRandomVal then begin
        SetLength(vCentroids[i], Length(aData[j]));
        for Index := 0 to Length(aData[j]) - 1 do begin
          vCentroids[i][Index] := aData[j][Index];
        end;
        Break;
      end;
    end;
  end;

  Result := vCentroids;
end;

function AssignClusters(const aData: TAIDatasetClustering; const aCentroids: TCentroids): TArray<Integer>;
var
  i, j, vClosest: Integer;
  vMinDist, vDist: Double;
  vClusters: TArray<Integer>;
begin
  SetLength(vClusters, Length(aData));
  for i := 0 to Length(aData) - 1 do begin
    vClosest := 0;
    vMinDist := CalculateEuclideanDistance(aData[i], aCentroids[0]);
    for j := 1 to Length(aCentroids) - 1 do begin
      vDist := CalculateEuclideanDistance(aData[i], aCentroids[j]);
      if vDist < vMinDist then begin
        vMinDist := vDist;
        vClosest := j;
      end;
    end;
    vClusters[i] := vClosest;
  end;
  Result := vClusters;
end;

function UpdateCentroids(const aData: TAIDatasetClustering; const aClusters: TArray<Integer>; aK: Integer): TCentroids;
var
  i, j  : Integer;
  vCentroids: TCentroids;
  vSums: TArray<TAISampleAtr>;
  vCount: TArray<Integer>;
begin
  SetLength(vCentroids, aK);
  SetLength(vSums, aK);
  SetLength(vCount, aK);

  for i := 0 to aK - 1 do begin
    SetLength(vSums[i], Length(aData[0]));
    for j := 0 to Length(vSums[i]) - 1 do begin
      vSums[i][j] := 0;
    end;
    vCount[i] := 0;
  end;

  for i := 0 to Length(aData) - 1 do begin
    for j := 0 to Length(aData[i]) - 1 do begin
      vSums[aClusters[i]][j] := vSums[aClusters[i]][j] + aData[i][j];
    end;
    Inc(vCount[aClusters[i]]);
  end;

  for i := 0 to aK - 1 do begin
    if vCount[i] > 0 then begin
      SetLength(vCentroids[i], Length(vSums[i]));
      for j := 0 to Length(vSums[i]) - 1 do begin
        vCentroids[i][j] := vSums[i][j] / vCount[i];
      end;
    end;
  end;

  Result := vCentroids;
end;

function CalculateInertia(const aData: TAIDatasetClustering; const aClusters: TArray<Integer>; const aCentroids: TCentroids): Double;
var
  i : Integer;
  vInertia, vDist: Double;
begin
  vInertia := 0.0;
  for i := 0 to Length(aData) - 1 do begin
    vDist := CalculateEuclideanDistance(aData[i], aCentroids[aClusters[i]]);
    vInertia := vInertia + Power(vDist, 2);
  end;
  Result := vInertia;
end;

function KMeans(aData: String; aK, aMaxIterations, aNumInitializations: Integer; aHasHeader : Boolean = True): TArray<Integer>;
var
  vDataSet : TAIDatasetClustering;
  vNormRange : TNormalizationRange;
begin
  LoadDataset(aData, vDataSet, vNormRange, aHasHeader);
  Result := KMeans(vDataSet, aK, aMaxIterations, aNumInitializations);
end;

function KMeans(aData: TDataSet; aK, aMaxIterations, aNumInitializations: Integer): TArray<Integer>;
var
  vDataSet : TAIDatasetClustering;
  vNormRange : TNormalizationRange;
begin
  if aData.RecordCount = 0 then begin
    raise Exception.Create('Dataset is empty.');
  end;

  LoadDataset(aData, vDataSet, vNormRange);

  Result := KMeans(vDataSet, aK, aMaxIterations, aNumInitializations);
end;


function KMeans(aData: TAIDatasetClustering; aK, aMaxIterations, aNumInitializations: Integer): TArray<Integer>;
var
  vBestCentroids, vCentroids: TCentroids;
  vBestClusters, vClusters, vOldClusters: TArray<Integer>;
  vBestInertia, vCurrentInertia: Double;
  i, j: Integer;
begin
  vBestInertia := Infinity;

  for j := 0 to aNumInitializations - 1 do begin

    vCentroids := InitializeCentroidsPlusPlus(aData, aK);

    for i := 0 to aMaxIterations - 1 do begin
      vClusters := AssignClusters(aData, vCentroids);

      if (i > 20) and (ArraysAreEqual(vClusters, vOldClusters)) then begin
        Break;
      end;

      vOldClusters := vClusters;
      vCentroids := UpdateCentroids(aData, vClusters, aK);
    end;


    vCurrentInertia := CalculateInertia(aData, vClusters, vCentroids);


    if vCurrentInertia < vBestInertia then begin
      vBestInertia := vCurrentInertia;
      vBestClusters := vClusters;
      vBestCentroids := vCentroids;
    end;
  end;

  Result := vBestClusters;
end;

end.
