unit UAITypes;

interface

uses
  System.Generics.Collections;

type
  TAISampleAtr = TArray<Double>;
  TAISamplesAtr = TArray<TAISampleAtr>;

  TAILabelsClassification = TArray<String>;
  TAISampleClassification = TPair<TAISampleAtr, string>;
  TAIDatasetClassification = TArray<TAISampleClassification>;

  TAILabelsRegression = TArray<Double>;
  TAISampleRegression = TPair<TAISampleAtr, Double>;
  TAIDatasetRegression = TArray<TAISampleRegression>;

  TAIDatasetClustering = TArray<TAISampleAtr>;

  TAIDatasetRecommendation = TArray<TAISampleAtr>;

  TKernelType = (ktLinear, ktRBF);

  TSplitCriterion = (scGini, scEntropy);

  TUserScoreAggregationMethod = (amMode, amWeightedAverage, amSimpleSum);

  TDistanceMode = (
    dmManhattan,
    dmEuclidean,
    dmCosine,
    dmJaccard,
    dmPearson
  );

  TNormalizationRange = record
    MinValues, MaxValues: TAISampleAtr;
  end;


implementation

end.
