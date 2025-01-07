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
  i, j, Index: Integer;
  Centroids: TCentroids;
begin
  SetLength(Centroids, aK);
  Randomize;
  for i := 0 to aK - 1 do  begin
    Index := Random(Length(aData));
    SetLength(Centroids[i], Length(aData[Index]));
    for j := 0 to Length(aData[Index]) - 1 do
      Centroids[i][j] := aData[Index][j];
  end;
  Result := Centroids;
end;

function InitializeCentroidsPlusPlus(const aData: TAIDatasetClustering; aK: Integer): TCentroids;
var
  Centroids: TCentroids;
  Distances: TArray<Double>;
  SumDistances, RandomVal, PartialSum: Double;
  i, j, Index: Integer;
begin
  SetLength(Centroids, aK);
  Randomize;

  
  Index := Random(Length(aData));
  SetLength(Centroids[0], Length(aData[Index]));
  for j := 0 to Length(aData[Index]) - 1 do begin
    Centroids[0][j] := aData[Index][j];
  end;

  for i := 1 to aK - 1 do begin
    SetLength(Distances, Length(aData));
    SumDistances := 0;

    
    for j := 0 to Length(aData) - 1 do begin
      Distances[j] := CalcularDistanciaEuclidiana(aData[j], Centroids[0]);
      for Index := 1 to i - 1 do
        Distances[j] := Min(Distances[j], CalcularDistanciaEuclidiana(aData[j], Centroids[Index]));
      SumDistances := SumDistances + Distances[j];
    end;

    
    RandomVal := Random * SumDistances;
    PartialSum := 0;
    for j := 0 to Length(aData) - 1 do begin
      PartialSum := PartialSum + Distances[j];
      if PartialSum >= RandomVal then begin
        SetLength(Centroids[i], Length(aData[j]));
        for Index := 0 to Length(aData[j]) - 1 do begin
          Centroids[i][Index] := aData[j][Index];
        end;
        Break;
      end;
    end;
  end;

  Result := Centroids;
end;

function AssignClusters(const aData: TAIDatasetClustering; const aCentroids: TCentroids): TArray<Integer>;
var
  i, j, Closest: Integer;
  MinDist, Dist: Double;
  Clusters: TArray<Integer>;
begin
  SetLength(Clusters, Length(aData));
  for i := 0 to Length(aData) - 1 do begin
    Closest := 0;
    MinDist := CalcularDistanciaEuclidiana(aData[i], aCentroids[0]);
    for j := 1 to Length(aCentroids) - 1 do begin
      Dist := CalcularDistanciaEuclidiana(aData[i], aCentroids[j]);
      if Dist < MinDist then begin
        MinDist := Dist;
        Closest := j;
      end;
    end;
    Clusters[i] := Closest;
  end;
  Result := Clusters;
end;

function UpdateCentroids(const aData: TAIDatasetClustering; const aClusters: TArray<Integer>; aK: Integer): TCentroids;
var
  i, j  : Integer;
  Centroids: TCentroids;
  Sums: TArray<TAISampleAtr>;
  Count: TArray<Integer>;
begin
  SetLength(Centroids, aK);
  SetLength(Sums, aK);
  SetLength(Count, aK);

  
  for i := 0 to aK - 1 do begin
    SetLength(Sums[i], Length(aData[0]));
    for j := 0 to Length(Sums[i]) - 1 do begin
      Sums[i][j] := 0;
    end;
    Count[i] := 0;
  end;

  
  for i := 0 to Length(aData) - 1 do begin
    for j := 0 to Length(aData[i]) - 1 do begin
      Sums[aClusters[i]][j] := Sums[aClusters[i]][j] + aData[i][j];
    end;
    Inc(Count[aClusters[i]]);
  end;

  
  for i := 0 to aK - 1 do begin
    if Count[i] > 0 then begin
      SetLength(Centroids[i], Length(Sums[i]));
      for j := 0 to Length(Sums[i]) - 1 do begin
        Centroids[i][j] := Sums[i][j] / Count[i];
      end;
    end;
  end;

  Result := Centroids;
end;

function CalculateInertia(const aData: TAIDatasetClustering; const Clusters: TArray<Integer>; const Centroids: TCentroids): Double;
var
  i : Integer;
  Inertia, Dist: Double;
begin
  Inertia := 0.0;
  for i := 0 to Length(aData) - 1 do begin
    Dist := CalcularDistanciaEuclidiana(aData[i], Centroids[Clusters[i]]);
    Inertia := Inertia + Power(Dist, 2);
  end;
  Result := Inertia;
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
  BestCentroids, Centroids: TCentroids;
  BestClusters, Clusters, OldClusters: TArray<Integer>;
  BestInertia, CurrentInertia: Double;
  i, j: Integer;
begin
  BestInertia := Infinity;

  for j := 0 to aNumInitializations - 1 do begin
    
    Centroids := InitializeCentroidsPlusPlus(aData, aK);

    for i := 0 to aMaxIterations - 1 do begin
      Clusters := AssignClusters(aData, Centroids);

      if (i > 20) and (ArraysAreEqual(Clusters, OldClusters)) then begin
        Break;
      end;

      OldClusters := Clusters;
      Centroids := UpdateCentroids(aData, Clusters, aK);
    end;

    
    CurrentInertia := CalculateInertia(aData, Clusters, Centroids);

    
    if CurrentInertia < BestInertia then begin
      BestInertia := CurrentInertia;
      BestClusters := Clusters;
      BestCentroids := Centroids;
    end;
  end;

  Result := BestClusters;
end;

end.
