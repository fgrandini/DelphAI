unit UAISelector;

interface

uses
  System.Generics.Collections, System.Variants, UAITypes, UDecisionTree,
  System.JSON, UNaiveBayes, ULinearRegression, URidgeRegression, URecommender, UKNN,
  Data.DB;

type

  //------------------------  CLASSIFICATION


  TClassResult = record
    Name : String;
    Tests,
    TruePositives,
    FalsePositives,
    FalseNegatives : Integer;
  end;

  TAIClassificationTest = class
  private
    FFinished : Boolean;
    FResults  : TDictionary<String, TClassResult>;
  public
    constructor Create;
    destructor Destroy; override;
    procedure ProcessResult(aPredictedClass, aCorrectClass : String);
    function Accuracy : Double;
    property Results  : TDictionary<String, TClassResult> read FResults write FResults;
    property Finished : Boolean read FFinished write FFinished;
  end;

  TAIClassificationModelKNN = class(TAIClassificationTest)
  private
    FK : Integer;
    FModel : TKNNClassification;
  public
    constructor Create(aK : Integer);
    destructor Destroy; override;
    property K : Integer read FK;
  end;

  TAIClassificationModelTree = class(TAIClassificationTest)
  private
    FDepth: Integer;
    FSplitCriterion : TSplitCriterion;
    FModel : TDecisionTree;
  public
    destructor Destroy; override;
    constructor Create(aDepth: Integer; aSplitCriterion : TSplitCriterion);
    function TreeToJSON : TJSONObject;
    property Depth : Integer read FDepth;
    property SplitCriterion : TSplitCriterion read FSplitCriterion;
  end;

  TAIClassificationModelNaive = class(TAIClassificationTest)
  private
    FModel : TGaussianNaiveBayes;
  public
    destructor Destroy; override;
    function ToJSONObject: TJSONObject;
  end;

  TAIClassificationModels = class
  private
    FLstModels : TList<TAIClassificationTest>;
  public
    procedure AddKNN(aK : Integer);
    procedure AddTree(aDepth: Integer; aSplitCriterion: TSplitCriterion);
    procedure AddNaiveBayes;
    constructor Create;
    destructor Destroy; override;
    property LstModels : TList<TAIClassificationTest> read FLstModels;
  end;

  TAIClassificationSelector = class
  private
    FModels : TAIClassificationModels;
    FTrainDatas,
    FTestDatas : TList<TAIDatasetClassification>;
    FDataset : TAIDatasetClassification;
    FNormalizationRange : TNormalizationRange;
    procedure InitializeKNNTest(aModelKNN : TAIClassificationModelKNN);
    procedure InitializeTreeTest(aModelTree : TAIClassificationModelTree);
    procedure InitializeNaiveBayesTest(aModelNaive : TAIClassificationModelNaive);
    procedure CreateFs;
  public
    procedure RunTests(aCsvResultFile, aLogFile : String;
                       aMaxThreads : Integer = 0;
                       aPercDatasetTest : Integer = 25;
                       aRandomDataset : Boolean = True;
                       aCrossValidation : Boolean = True);
    constructor Create(aDataset : TAIDatasetClassification; aNormalizationRange : TNormalizationRange); overload;
    constructor Create(aDataset : String; aHasHeader : Boolean = True); overload;
    constructor Create(aDataset : TDataSet); overload;
    destructor Destroy; override;

    property Models : TAIClassificationModels read FModels;
    property Dataset : TAIDatasetClassification read FDataset;
  end;



  //------------------------  REGRESSION

  TAIRegressionTest = class
  private
    FFinished : Boolean;
    FSumSquaredErrors: Double;
    FSumAbsoluteErrors: Double;
    FSumSquaredTotal: Double;
    FSumCorrectValues: Double;
    FSampleCount: Integer;
    FR2, FMAE, FMSE, FRMSE : Double;
    FCorrectValues: TList<Double>;
  public
    constructor Create;
    destructor Destroy; override;
    procedure ProcessResult(aPredictedValue, aCorrectValue : Double);
    procedure GenerateMetrics;
    property Finished : Boolean read FFinished write FFinished;
    property R2 : Double read FR2 write FR2;
    property MAE : Double read FMAE write FMAE;
    property MSE : Double read FMSE write FMSE;
    property RMSE : Double read FRMSE write FRMSE;
  end;

  TAIRegressionModelLinear = class(TAIRegressionTest)
  private
    FModel : TLinearRegression;
  public
    destructor Destroy; override;
    function ToJSONObject: TJSONObject;
  end;

  TAIRegressionModelRidge = class(TAIRegressionTest)
  private
    FAlfa : Double;
    FModel : TRidgeRegression;
  public
    function ToJSONObject: TJSONObject;
    constructor Create(aAlfa : Double = 1);
    destructor Destroy; override;
  end;

  TAIRegressionModelKNN = class(TAIRegressionTest)
  private
    FK : Integer;
    FModel : TKNNRegression;
  public
    constructor Create(aK : Integer);
    destructor Destroy; override;
    property K : Integer read FK;
  end;

  TAIRegressionModels = class
  private
    FLstModels : TList<TAIRegressionTest>;
  public
    procedure AddKNN(aK : Integer);
    procedure AddLinearRegression;
    procedure AddRidge(aAlfa : Double = 1);
    constructor Create;
    destructor Destroy; override;
    property LstModels : TList<TAIRegressionTest> read FLstModels;
  end;

  TAIRegressionSelector = class
  private
    FModels : TAIRegressionModels;
    FNormalizationRange : TNormalizationRange;
    FTrainDatas,
    FTestDatas : TList<TAIDatasetRegression>;
    FDataset : TAIDatasetRegression;
    procedure InitializeKNNTest(aModelKNN : TAIRegressionModelKNN);
    procedure InitializeLinearRegressionTest(aModelLinear : TAIRegressionModelLinear);
    procedure InitializeLinearRidgeTest(aModelRidge : TAIRegressionModelRidge);
    procedure CreateFs;
  public
    procedure RunTests(aCsvResultFile, aLogFile : String;
                                          aMaxThreads : Integer = 0;
                                          aPercDatasetTest : Integer = 25;
                                          aRandomDataset : Boolean = True;
                                          aCrossValidation : Boolean = True);
    constructor Create(aDataset : TAIDatasetRegression; aNormalizationRange : TNormalizationRange); overload;
    constructor Create(aDataset : String; aHasHeader : Boolean = True); overload;
    constructor Create(aDataset : TDataSet); overload;
    destructor Destroy; override;

    property Models : TAIRegressionModels read FModels;
    property Dataset : TAIDatasetRegression read FDataset;
  end;

  //------------------------  RECOMMENDATION

  TAIRecommendationModel = class
  private
    FAccurary : Double;
    FItemsToRecommendCount,
    FK : Integer;
    FAggregationMode : TUserScoreAggregationMethod;
    FDistanceMethod : TDistanceMode;
    FModel : TRecommender;
    FItem : Boolean;
  public
    property Accuracy : Double read FAccurary;
    property Model : TRecommender read FModel write FModel;
    constructor Create(aItemsToRecommendCount, aK: Integer; aAggregMethod: TUserScoreAggregationMethod; aDistanceMethod: TDistanceMode; aItem : Boolean);
    function ToJSONObject: TJSONObject;
    destructor Destroy; override;
  end;

  TAIRecommendationModels = class
  private
    FLstModels : TList<TAIRecommendationModel>;
  public
    procedure AddItemItem(aItemsToRecommendCount : Integer; aDistanceMethod : TDistanceMode = dmManhattan);
    procedure AddUserUser(aItemsToRecommendCount, aK : Integer; aAggregMethod : TUserScoreAggregationMethod = amWeightedAverage; aDistanceMethod : TDistanceMode = dmManhattan);
    constructor Create;
    destructor Destroy; override;
    property LstModels : TList<TAIRecommendationModel> read FLstModels;
  end;

  TAIRecommendationSelector = class
  private
    FModels : TAIRecommendationModels;
    FDataset : TAIDatasetRecommendation;
    FNormalizationRange : TNormalizationRange;
  public
    procedure RunTestsUserUser(aCsvResultFile, aLogFile : String;
                     aMaxThreads : Integer = 0);
    procedure RunTestsItemItem(aCsvResultFile, aLogFile : String;
                     aMaxThreads : Integer = 0);
    constructor Create(aDataset : TAIDatasetRecommendation; aNormalizationRange : TNormalizationRange); overload;
    constructor Create(aDataset : String; aHasHeader : Boolean = True); overload;
    constructor Create(aDataset : TDataSet); overload;
    destructor Destroy; override;

    property Models : TAIRecommendationModels read FModels;
    property Dataset : TAIDatasetRecommendation read FDataset;
  end;

  procedure SplitDataset(aDataset: TAIDatasetClassification; aTestPercent: Double; aGetRandomSamples: Boolean;
    aTrainDatas, aTestDatas: TList<TAIDatasetClassification>; aBaseCount: Integer); overload;
  procedure SplitDataset(aDataset: TAIDatasetRegression; aTestPercent: Double; aGetRandomSamples: Boolean;
    aTrainDatas, aTestDatas: TList<TAIDatasetRegression>; aBaseCount: Integer); overload;


implementation

uses
  System.SysUtils, System.Math, System.Threading, UAuxGlobal, ULogger, System.Classes;

{ TAIClassificationModels }

procedure TAIClassificationModels.AddKNN(aK: Integer);
begin
  FLstModels.Add(TAIClassificationModelKNN.Create(aK))
end;

procedure TAIClassificationModels.AddTree(aDepth: Integer; aSplitCriterion: TSplitCriterion);
begin
  FLstModels.Add(TAIClassificationModelTree.Create(aDepth, aSplitCriterion))
end;

procedure TAIClassificationModels.AddNaiveBayes;
begin
  FLstModels.Add(TAIClassificationModelNaive.Create)
end;

constructor TAIClassificationModels.Create;
begin
  FLstModels := TList<TAIClassificationTest>.Create;
end;

destructor TAIClassificationModels.Destroy;
var
  i : Integer;
begin
  for i := 0 to FLstModels.Count-1 do begin
    FLstModels[i].Free;
  end;
  FLstModels.Free;
  inherited;
end;

{ TAIClassification }

procedure TAIClassificationSelector.CreateFs;
begin
  FModels     := TAIClassificationModels.Create;
  FTrainDatas := TList<TAIDatasetClassification>.Create;
  FTestDatas  := TList<TAIDatasetClassification>.Create;
end;

constructor TAIClassificationSelector.Create(aDataset: TAIDatasetClassification; aNormalizationRange: TNormalizationRange);
begin
  FDataset := Copy(aDataset);
  FNormalizationRange := aNormalizationRange;
  if Length(FDataset) = 0 then begin
    raise Exception.Create('Dataset is empty.');
  end;
  CreateFs;
end;

constructor TAIClassificationSelector.Create(aDataset: String; aHasHeader: Boolean);
begin
  LoadDataset(aDataset, FDataset, FNormalizationRange, aHasHeader);
  if Length(FDataset) = 0 then begin
    raise Exception.Create('Dataset is empty.');
  end;
  CreateFs;
end;

constructor TAIClassificationSelector.Create(aDataset: TDataSet);
begin
  if aDataset.RecordCount = 0 then begin
    raise Exception.Create('Dataset is empty.');
  end;
  LoadDataset(aDataset, FDataset, FNormalizationRange);
  CreateFs;
end;

destructor TAIClassificationSelector.Destroy;
begin
  FModels.Free;
  FTrainDatas.Free;
  FTestDatas.Free;
  inherited;
end;

procedure TAIClassificationSelector.InitializeTreeTest(aModelTree : TAIClassificationModelTree);
var
  i, j : Integer;
  vTree: TDecisionTree;
  vTrainData, vTestData : TAIDatasetClassification;
begin
  for i := 0 to FTrainDatas.Count-1 do begin
    vTrainData := FTrainDatas[i];
    vTestData := FTestDatas[i];
    vTree := TDecisionTree.Create(aModelTree.Depth, aModelTree.FSplitCriterion);
    try
      vTree.Train(vTrainData, FNormalizationRange);
      for j := Low(vTestData) to High(vTestData) do begin
        aModelTree.ProcessResult(vTree.Predict(vTestData[j].Key, True), vTestData[j].Value);
      end;
      vTree.ClearDataset;
      if aModelTree.FModel <> nil then begin
        aModelTree.FModel.Free;
      end;
      aModelTree.FModel := vTree;
      aModelTree.Finished := True;
    except
      vTree.Free;
      vTree.ClearDataset;
      raise;
    end;
  end;
end;

procedure TAIClassificationSelector.InitializeNaiveBayesTest(aModelNaive : TAIClassificationModelNaive);
var
  i, j : Integer;
  vNaiveBayes : TGaussianNaiveBayes;
  vTrainData, vTestData : TAIDatasetClassification;
begin
  for i := 0 to FTrainDatas.Count-1 do begin
    vTrainData := FTrainDatas[i];
    vTestData := FTestDatas[i];
    vNaiveBayes := TGaussianNaiveBayes.Create;
    try
      vNaiveBayes.Train(vTrainData, FNormalizationRange);
      for j := Low(vTestData) to High(vTestData) do begin
        aModelNaive.ProcessResult(vNaiveBayes.Predict(vTestData[j].Key, True), vTestData[j].Value);
      end;
      if aModelNaive.FModel <> nil then begin
        aModelNaive.FModel.Free;
      end;
      aModelNaive.FModel := vNaiveBayes;
    except
      vNaiveBayes.Free;
      vNaiveBayes.ClearDataset;
      raise;
    end;
  end;
end;

procedure TAIClassificationSelector.InitializeKNNTest(aModelKNN : TAIClassificationModelKNN);
var
  i, j : Integer;
  vKNN : TKNNClassification;
  vTrainData, vTestData : TAIDatasetClassification;
begin
  for i := 0 to FTrainDatas.Count-1 do begin
    vTrainData := FTrainDatas[i];
    vTestData := FTestDatas[i];
    vKNN := TKNNClassification.Create(vTrainData, FNormalizationRange, aModelKNN.K);
    try
      for j := Low(vTestData) to High(vTestData) do begin
        aModelKNN.ProcessResult(vKNN.Predict(vTestData[j].Key, True), vTestData[j].Value);
      end;
      if aModelKNN.FModel <> nil then begin
        aModelKNN.FModel.Free;
      end;
      aModelKNN.FModel := vKNN;
      aModelKNN.Finished := True;
    except
      vKNN.Free;
      vKNN.ClearDataset;
      raise;
    end;
  end;
end;

procedure TAIClassificationSelector.RunTests(aCsvResultFile, aLogFile : String;
                                             aMaxThreads : Integer = 0;
                                             aPercDatasetTest : Integer = 25;
                                             aRandomDataset : Boolean = True;
                                             aCrossValidation : Boolean = True);
var
  vLine,
  vClassName : String;
  i, vNextFilter,
  vBaseCount : Integer;
  vLogger : TLogger;
  vCSVFile : TStringList;
  vResult : TClassResult;
begin
  if aPercDatasetTest > 90 then begin
    raise Exception.Create('The percentage of the test base should not be more than 0.9.');
  end;
  if aPercDatasetTest < 10 then begin
    raise Exception.Create('The percentage of the test base should not be less than 0.1.');
  end;
  if FModels.FLstModels.Count = 0 then begin
    raise Exception.Create('Add a model to test before running the tests.');
  end;
  if aMaxThreads = 0 then begin
    aMaxThreads := PCThreadCount;
  end else begin
    aMaxThreads := Min(aMaxThreads, PCThreadCount);
  end;
  vLogger := TLogger.Create(aLogFile);
  vCSVFile := TStringList.Create;
  try
    vLogger.Log('Spliting Dataset.');
    if aCrossValidation then begin
      vBaseCount := 100 div aPercDatasetTest;
    end else begin
      vBaseCount := 1;
    end;
    SplitDataset(FDataset, aPercDatasetTest / 100, aRandomDataset, FTrainDatas, FTestDatas, vBaseCount);
    vLogger.Log('Dataset splited.');
    vLogger.Log('Samples to train: ' + IntToStr(High(FTrainDatas[0])));
    vLogger.Log('Samples to test: ' + IntToStr(High(FTestDatas[0])));
    vNextFilter := 0;
    while vNextFilter < FModels.FLstModels.Count do begin
      if vNextFilter + aMaxThreads > FModels.FLstModels.Count then begin
        aMaxThreads := FModels.FLstModels.Count - vNextFilter;
      end;
      TParallel.For(vNextFilter, vNextFilter + aMaxThreads - 1,
        procedure(i: Integer)
        var
          vParameters : String;
        begin
          if FModels.FLstModels[i] is TAIClassificationModelNaive then begin
            vParameters := ' model "Naive Bayes".';
            vLogger.Log('Starting' + vParameters);
            InitializeNaiveBayesTest(TAIClassificationModelNaive(FModels.FLstModels[i]));
          end else if FModels.FLstModels[i] is TAIClassificationModelKNN then begin
            vParameters := ' model "KNN".'
            + #13#10 + 'K: ' + IntToStr(TAIClassificationModelKNN(FModels.FLstModels[i]).K);
            vLogger.Log('Starting' + vParameters);
            InitializeKNNTest(TAIClassificationModelKNN(FModels.FLstModels[i]));
          end else if FModels.FLstModels[i] is TAIClassificationModelTree then begin
            vParameters := ' model "Tree decision".'
            + #13#10 + 'Depth: ' + IntToStr(TAIClassificationModelTree(FModels.FLstModels[i]).FDepth)
            + #13#10 + 'Split Criterion: ' + SplitCriterionToString(TAIClassificationModelTree(FModels.FLstModels[i]).FSplitCriterion);
            vLogger.Log('Starting' + vParameters);
            InitializeTreeTest(TAIClassificationModelTree(FModels.FLstModels[i]));
          end;
          vLogger.Log('Finish' + vParameters + #13#10 +
                      'Accuracy: ' + FormatFloat('##0.000', FModels.FLstModels[i].Accuracy));
        end
      );
    vNextFilter := vNextFilter + aMaxThreads;
    end;

    if aCsvResultFile <> '' then begin
      vLine := 'Model,Parameters,Accuracy';

      for vResult in FModels.FLstModels[0].Results.Values do begin
        vClassName := StringReplace(vResult.Name, ',', '', [rfReplaceAll]);
        vLine := vLine + ',Tests class: ' + vClassName +
                         ',True Positives class: ' + vClassName +
                         ',False Negatives class: ' + vClassName+
                         ',False Positives class: ' + vClassName;
      end;
      vCSVFile.Add(vLine);

      for i := 0 to FModels.FLstModels.Count-1 do begin
        if FModels.FLstModels[i] is TAIClassificationModelNaive then begin
          vLine := 'Naive Bayes,';
        end else if FModels.FLstModels[i] is TAIClassificationModelKNN then begin
          vLine := 'KNN,K=' + IntToStr(TAIClassificationModelKNN(FModels.FLstModels[i]).K);
        end else if FModels.FLstModels[i] is TAIClassificationModelTree then begin
          vLine := 'Tree Decision,Depth=' + IntToStr(TAIClassificationModelTree(FModels.FLstModels[i]).Depth) + '-SplitCriterion=' +
                    SplitCriterionToString(TAIClassificationModelTree(FModels.FLstModels[i]).FSplitCriterion);
        end;
        vLine := vLine + ',' + StringReplace(FormatFloat('##0.00', FModels.FLstModels[i].Accuracy), ',', '.', []);

        for vResult in FModels.FLstModels[i].Results.Values do begin
          vLine := vLine +
                    ',' + IntToStr(vResult.Tests) +
                    ',' + IntToStr(vResult.TruePositives) +
                    ',' + IntToStr(vResult.FalseNegatives)+
                    ',' + IntToStr(vResult.FalsePositives);
        end;

        vCSVFile.Add(vLine);
      end;
      vCSVFile.SaveToFile(aCsvResultFile);
    end;
  finally
    vLogger.Free;
    vCSVFile.Free;
  end;
end;

constructor TAIClassificationModelKNN.Create(aK: Integer);
begin
  FK := aK;
  inherited Create;
end;

procedure SplitDataset(aDataset: TAIDatasetClassification; aTestPercent: Double; aGetRandomSamples: Boolean;
    aTrainDatas, aTestDatas: TList<TAIDatasetClassification>; aBaseCount: Integer);
var
  vTrainSize, vTestSize, vLastTest,
  i, j, vNextTrain, vNextTest : Integer;
  vRandomIndexes, vIndexes: TList<Integer>;
  vTrainData, vTestData, vCleanData : TAIDatasetClassification;
begin
  if (aTestPercent < 0) or (aTestPercent > 1) then begin
    raise Exception.Create('The percentage of the test base must be between 0 and 1.');
  end;

  aTrainDatas.Clear;
  aTestDatas.Clear;
  vTestSize := Trunc(Length(aDataset) * aTestPercent);
  vTrainSize := Length(aDataset) - vTestSize;
  SetLength(vCleanData, 0);
  vIndexes := TList<Integer>.Create;
  try
    for i := 0 to Length(aDataset) - 1 do begin
      vIndexes.Add(i);
    end;

    if aGetRandomSamples then begin
      vRandomIndexes := TList<Integer>.Create;
      try
        while vIndexes.Count > 0 do begin
          j := Random(vIndexes.Count);
          vRandomIndexes.Add(vIndexes[j]);
          vIndexes.Delete(j);
        end;
        vIndexes.Free;
        vIndexes := vRandomIndexes;
      except
        vRandomIndexes.Free;
        raise;
      end;
    end;

    vLastTest := -1;
    for i := 0 to aBaseCount-1 do begin
      vTrainData := Copy(vCleanData);
      vTestData  := Copy(vCleanData);
      vNextTrain := 0;
      vNextTest := 0;

      SetLength(vTrainData, vTrainSize);
      SetLength(vTestData, vTestSize);

      for j := 0 to vLastTest do begin
        if vNextTrain < vTrainSize then begin
          vTrainData[vNextTrain] := aDataset[vIndexes[j]];
          inc(vNextTrain);
        end;
      end;

      for j := vLastTest+1 to vLastTest + vTestSize do begin
        if (vNextTest < vTestSize) then begin
          vTestData[vNextTest] := aDataset[vIndexes[j]];
          inc(vNextTest);
        end;
      end;

      vLastTest := vLastTest + vTestSize;

      for j := vLastTest+1 to Length(aDataset) - 1 do begin
        if vNextTrain < vTrainSize then begin
          vTrainData[vNextTrain] := aDataset[vIndexes[j]];
          inc(vNextTrain);
        end;
      end;
      aTrainDatas.Add(vTrainData);
      aTestDatas.Add(vTestData);
    end;
  finally
    vIndexes.Free;
  end;
end;

procedure SplitDataset(aDataset: TAIDatasetRegression; aTestPercent: Double; aGetRandomSamples: Boolean;
    aTrainDatas, aTestDatas: TList<TAIDatasetRegression>; aBaseCount: Integer); overload;
var
  vTrainSize, vTestSize, vLastTest,
  i, j, vNextTrain, vNextTest : Integer;
  vRandomIndexes, vIndexes: TList<Integer>;
  vTrainData, vTestData, vCleanData : TAIDatasetRegression;
begin
  if (aTestPercent < 0) or (aTestPercent > 1) then begin
    raise Exception.Create('The percentage of the test base must be between 0 and 1.');
  end;

  aTrainDatas.Clear;
  aTestDatas.Clear;
  vTestSize := Trunc(Length(aDataset) * aTestPercent);
  vTrainSize := Length(aDataset) - vTestSize;
  SetLength(vCleanData, 0);
  vIndexes := TList<Integer>.Create;
  try
    for i := 0 to Length(aDataset) - 1 do begin
      vIndexes.Add(i);
    end;

    if aGetRandomSamples then begin
      vRandomIndexes := TList<Integer>.Create;
      try
        while vIndexes.Count > 0 do begin
          j := Random(vIndexes.Count);
          vRandomIndexes.Add(vIndexes[j]);
          vIndexes.Delete(j);
        end;
        vIndexes.Free;
        vIndexes := vRandomIndexes;
      except
        vRandomIndexes.Free;
        raise;
      end;
    end;

    vLastTest := -1;
    for i := 0 to aBaseCount-1 do begin
      vTrainData := Copy(vCleanData);
      vTestData  := Copy(vCleanData);
      vNextTrain := 0;
      vNextTest := 0;

      SetLength(vTrainData, vTrainSize);
      SetLength(vTestData, vTestSize);

      for j := 0 to vLastTest do begin
        if vNextTrain < vTrainSize then begin
          vTrainData[vNextTrain] := aDataset[vIndexes[j]];
          inc(vNextTrain);
        end;
      end;

      for j := vLastTest+1 to vLastTest + vTestSize do begin
        if (vNextTest < vTestSize) then begin
          vTestData[vNextTest] := aDataset[vIndexes[j]];
          inc(vNextTest);
        end;
      end;

      vLastTest := vLastTest + vTestSize;

      for j := vLastTest+1 to Length(aDataset) - 1 do begin
        if vNextTrain < vTrainSize then begin
          vTrainData[vNextTrain] := aDataset[vIndexes[j]];
          inc(vNextTrain);
        end;
      end;
      aTrainDatas.Add(vTrainData);
      aTestDatas.Add(vTestData);
    end;
  finally
    vIndexes.Free;
  end;
end;

{ TAIClassificationModelTree }

constructor TAIClassificationModelTree.Create(aDepth: Integer;
  aSplitCriterion: TSplitCriterion);
begin
  FDepth := aDepth;
  FSplitCriterion := aSplitCriterion;
  inherited Create;
end;

procedure TAIRegressionSelector.CreateFs;
begin
  FModels     := TAIRegressionModels.Create;
  FTrainDatas := TList<TAIDatasetRegression>.Create;
  FTestDatas  := TList<TAIDatasetRegression>.Create;
end;

constructor TAIRegressionSelector.Create(aDataset: TAIDatasetRegression; aNormalizationRange: TNormalizationRange);
begin
  FDataset := Copy(aDataset);
  FNormalizationRange := aNormalizationRange;
  if Length(FDataset) = 0 then begin
    raise Exception.Create('Dataset is empty.');
  end;
  CreateFs;
end;

constructor TAIRegressionSelector.Create(aDataset: String; aHasHeader: Boolean);
begin
  LoadDataset(aDataset, FDataset, FNormalizationRange, aHasHeader);
  if Length(FDataset) = 0 then begin
    raise Exception.Create('Dataset is empty.');
  end;
  CreateFs;
end;

constructor TAIRegressionSelector.Create(aDataset: TDataSet);
begin
  if aDataset.RecordCount = 0 then begin
    raise Exception.Create('Dataset is empty.');
  end;
  LoadDataset(aDataset, FDataset, FNormalizationRange);
  CreateFs;
end;

destructor TAIRegressionSelector.Destroy;
begin
  FModels.Free;
  FTrainDatas.Free;
  FTestDatas.Free;
  inherited;
end;

procedure TAIRegressionSelector.RunTests(aCsvResultFile, aLogFile : String;
                                         aMaxThreads : Integer = 0;
                                         aPercDatasetTest : Integer = 25;
                                         aRandomDataset : Boolean = True;
                                         aCrossValidation : Boolean = True);
var
  vLine : String;
  i, vNextFilter,
  vBaseCount : Integer;
  vLogger : TLogger;
  vCSVFile : TStringList;
begin
  if aPercDatasetTest > 90 then begin
    raise Exception.Create('The percentage of the test base should not be more than 0.9.');
  end;
  if aPercDatasetTest < 10 then begin
    raise Exception.Create('The percentage of the test base should not be less than 0.1.');
  end;
  if FModels.FLstModels.Count = 0 then begin
    raise Exception.Create('Add a model to test before running the tests.');
  end;
  if aMaxThreads = 0 then begin
    aMaxThreads := PCThreadCount;
  end else begin
    aMaxThreads := Min(aMaxThreads, PCThreadCount);
  end;
  vLogger := TLogger.Create(aLogFile);
  vCSVFile := TStringList.Create;
  try
    vLogger.Log('Spliting Dataset.');
    if aCrossValidation then begin
      vBaseCount := 100 div aPercDatasetTest;
    end else begin
      vBaseCount := 1;
    end;
    SplitDataset(FDataset, aPercDatasetTest / 100, aRandomDataset, FTrainDatas, FTestDatas, vBaseCount);
    vLogger.Log('Dataset splited.');
    vLogger.Log('Samples to train: ' + IntToStr(High(FTrainDatas[0])));
    vLogger.Log('Samples to test: ' + IntToStr(High(FTestDatas[0])));
    vNextFilter := 0;
    while vNextFilter < FModels.FLstModels.Count do begin
      if vNextFilter + aMaxThreads > FModels.FLstModels.Count then begin
        aMaxThreads := FModels.FLstModels.Count - vNextFilter;
      end;
      TParallel.For(vNextFilter, vNextFilter + aMaxThreads - 1,
        procedure(i: Integer)
        var
          vParameters : String;
        begin
          if FModels.FLstModels[i] is TAIRegressionModelRidge then begin
            vParameters := ' model "Linear Ridge".'
            + #13#10 + 'Alfa: ' + FormatFloat('##0.000', TAIRegressionModelRidge(FModels.FLstModels[i]).FAlfa);
            vLogger.Log('Starting' + vParameters);
            InitializeLinearRidgeTest(TAIRegressionModelRidge(FModels.FLstModels[i]));
          end else if FModels.FLstModels[i] is TAIRegressionModelKNN then begin
            vParameters := ' model "KNN".'
            + #13#10 + 'K: ' + IntToStr(TAIRegressionModelKNN(FModels.FLstModels[i]).K);
            vLogger.Log('Starting' + vParameters);
            InitializeKNNTest(TAIRegressionModelKNN(FModels.FLstModels[i]));
          end else if FModels.FLstModels[i] is TAIRegressionModelLinear then begin
            vParameters := ' model "Linear Regression".';
            vLogger.Log('Starting' + vParameters);
            InitializeLinearRegressionTest(TAIRegressionModelLinear(FModels.FLstModels[i]));
          end;
          FModels.FLstModels[i].GenerateMetrics;

          vLogger.Log('Finish' + vParameters + #13#10 +
                      'R2: ' + FormatFloat('##0.000', FModels.FLstModels[i].FR2)+
                      'RMSE: ' + FormatFloat('##0.000', FModels.FLstModels[i].FRMSE)+
                      'MSE: ' + FormatFloat('##0.000', FModels.FLstModels[i].FMSE)+
                      'MAE: ' + FormatFloat('##0.000', FModels.FLstModels[i].FMAE));
        end
      );
    vNextFilter := vNextFilter + aMaxThreads;
    end;

    if aCsvResultFile <> '' then begin
      vLine := 'Model,Parameters,R2,RMSE,MSE,MAE';

      vCSVFile.Add(vLine);


      for i := 0 to FModels.FLstModels.Count-1 do begin
        if FModels.FLstModels[i] is TAIRegressionModelLinear then begin
          vLine := 'Linear Regression,';
        end else if FModels.FLstModels[i] is TAIRegressionModelKNN then begin
          vLine := 'KNN,K=' + IntToStr(TAIRegressionModelKNN(FModels.FLstModels[i]).K);
        end else if FModels.FLstModels[i] is TAIRegressionModelRidge then begin
          vLine := 'Linear Ridge,Alfa=' + StringReplace(FormatFloat('##0.000', TAIRegressionModelRidge(FModels.FLstModels[i]).FAlfa), ',', '.', []);
        end;
        vLine := vLine + ',' +
                  StringReplace(FormatFloat('##0.000', FModels.FLstModels[i].FR2), ',', '.', []) + ',' +
                  StringReplace(FormatFloat('##0.000', FModels.FLstModels[i].FRMSE), ',', '.', []) + ',' +
                  StringReplace(FormatFloat('##0.000', FModels.FLstModels[i].FMSE), ',', '.', []) + ',' +
                  StringReplace(FormatFloat('##0.000', FModels.FLstModels[i].FMAE), ',', '.', []);


        vCSVFile.Add(vLine);
      end;
      vCSVFile.SaveToFile(aCsvResultFile);
    end;
  finally
    vLogger.Free;
    vCSVFile.Free;
  end;
end;

destructor TAIRegressionTest.Destroy;
begin
  FCorrectValues.Free;
  inherited;
end;

procedure TAIRegressionTest.GenerateMetrics;
var
  vMeanCorrectValue, vR2Numerator, vR2Denominator: Double;
  vValue: Double;
begin
  if FSampleCount = 0 then
  begin
    Writeln('No samples processed.');
    Exit;
  end;

  vMeanCorrectValue := FSumCorrectValues / FSampleCount;

  FSumSquaredTotal := 0;
  for vValue in FCorrectValues do
  begin
    FSumSquaredTotal := FSumSquaredTotal + Sqr(vValue - vMeanCorrectValue);
  end;

  FMAE := FSumAbsoluteErrors / FSampleCount;
  FMSE := FSumSquaredErrors / FSampleCount;
  FRMSE := Sqrt(FMSE);

  vR2Numerator := FSumSquaredTotal - FSumSquaredErrors;
  vR2Denominator := FSumSquaredTotal;
  if vR2Denominator <> 0 then
    FR2 := vR2Numerator / vR2Denominator
  else
    FR2 := 0;
end;

procedure TAIRegressionSelector.InitializeKNNTest(aModelKNN : TAIRegressionModelKNN);
var
  i, j: Integer;
  vKNN : TKNNRegression;
  vTrainData, vTestData : TAIDatasetRegression;
begin
  for i := 0 to FTrainDatas.Count-1 do begin
    vTrainData := FTrainDatas[i];
    vTestData := FTestDatas[i];
    vKNN := TKNNRegression.Create(vTrainData, FNormalizationRange, aModelKNN.K);
    try
      for j := Low(vTestData) to High(vTestData) do begin
        aModelKNN.ProcessResult(vKNN.Predict(vTestData[j].Key, True), vTestData[j].Value);
      end;
      if aModelKNN.FModel <> nil then begin
        aModelKNN.FModel.Free;
      end;
      aModelKNN.FModel := vKNN;
      aModelKNN.Finished := True;
    except
      vKNN.Free;
      vKNN.ClearDataset;
      raise;
    end;
  end;
end;

procedure TAIRegressionSelector.InitializeLinearRegressionTest(aModelLinear : TAIRegressionModelLinear);
var
  i, j: Integer;
  vLinear : TLinearRegression;
  vTrainData, vTestData : TAIDatasetRegression;
begin
  for i := 0 to FTrainDatas.Count-1 do begin
    vTrainData := FTrainDatas[i];
    vTestData := FTestDatas[i];
    vLinear := TLinearRegression.Create;
    try
      vLinear.Train(vTrainData, FNormalizationRange);
      for j := Low(vTestData) to High(vTestData) do begin
        aModelLinear.ProcessResult(vLinear.Predict(vTestData[j].Key, True), vTestData[j].Value);
      end;
      if aModelLinear.FModel <> nil then begin
        aModelLinear.FModel.Free;
      end;
      aModelLinear.FModel := vLinear;
      aModelLinear.Finished := True;
    except
      vLinear.Free;
      vLinear.ClearDataset;
      raise;
    end;
  end;
end;

procedure TAIRegressionSelector.InitializeLinearRidgeTest(aModelRidge : TAIRegressionModelRidge);
var
  i, j: Integer;
  vRidge : TRidgeRegression;
  vTrainData, vTestData : TAIDatasetRegression;
begin
  for i := 0 to FTrainDatas.Count-1 do begin
    vTrainData := FTrainDatas[i];
    vTestData := FTestDatas[i];
    vRidge := TRidgeRegression.Create(aModelRidge.FAlfa);
    try
      vRidge.Train(vTrainData, FNormalizationRange);
      for j := Low(vTestData) to High(vTestData) do begin
        aModelRidge.ProcessResult(vRidge.Predict(vTestData[j].Key, True), vTestData[j].Value);
      end;
      if aModelRidge.FModel <> nil then begin
        aModelRidge.FModel.Free;
      end;
      aModelRidge.FModel := vRidge;
      aModelRidge.Finished := True;
    except
      vRidge.Free;
      vRidge.ClearDataset;
      raise;
    end;
  end;
end;

destructor TAIClassificationModelTree.Destroy;
begin
  FModel.Free;
  inherited;
end;

function TAIClassificationModelTree.TreeToJSON: TJSONObject;
begin
  if FModel <> nil then begin
    Result := FModel.TreeToJSON;
  end else begin
    Result := nil;
  end;
end;

{ TAIRegressionModelKNN }

constructor TAIRegressionModelKNN.Create(aK: Integer);
begin
  FK := aK;
  inherited Create;
end;

destructor TAIRegressionModelKNN.Destroy;
begin
  FModel.Free;
  inherited;
end;

{ TAIRegressionModels }

procedure TAIRegressionModels.AddKNN(aK: Integer);
begin
  FLstModels.Add(TAIRegressionModelKNN.Create(aK))
end;

procedure TAIRegressionModels.AddLinearRegression;
begin
  FLstModels.Add(TAIRegressionModelLinear.Create)
end;

procedure TAIRegressionModels.AddRidge(aAlfa : Double = 1);
begin
  FLstModels.Add(TAIRegressionModelRidge.Create(aAlfa))
end;

constructor TAIRegressionModels.Create;
begin
  FLstModels := TList<TAIRegressionTest>.Create;
end;

destructor TAIRegressionModels.Destroy;
var
  i : Integer;
begin
  for i := 0 to FLstModels.Count-1 do begin
    FLstModels[i].Free;
  end;
  FLstModels.Free;
  inherited;
end;

{ TAIRegressionModelRidge }

constructor TAIRegressionModelRidge.Create(aAlfa : Double = 1);
begin
  FAlfa := aAlfa;
  inherited Create;
end;

{ TAIClassificationModel }

function TAIClassificationTest.Accuracy: Double;
var
  vTests, vHits : Integer;
  vPair : TPair<string, TClassResult>;
  vClass : TClassResult;
begin
  vTests := 0;
  vHits := 0;
  for vPair in FResults do begin
    vClass := vPair.Value;
    inc(vTests, vClass.Tests);
    inc(vHits, vClass.TruePositives);
  end;
  if vTests = 0 then begin
    Result := 0;
  end else begin
    Result := vHits / vTests;
  end;
  Result := Result * 100;
end;

constructor TAIClassificationTest.Create;
begin
  FFinished := False;
  FResults := TDictionary<String, TClassResult>.Create;
end;

destructor TAIClassificationTest.Destroy;
begin
  FResults.Free;
  inherited;
end;

procedure TAIClassificationTest.ProcessResult(aPredictedClass, aCorrectClass: String);
var
  vResult : TClassResult;
begin
  if not FResults.TryGetValue(aCorrectClass, vResult) then begin
    vResult.Name           := aCorrectClass;
    vResult.Tests          := 0;
    vResult.TruePositives  := 0;
    vResult.FalsePositives := 0;
    vResult.FalseNegatives := 0;
  end;
  Inc(vResult.Tests);
  if aPredictedClass.Equals(aCorrectClass) then begin
    Inc(vResult.TruePositives);
    FResults.AddOrSetValue(aCorrectClass, vResult);
  end else begin
    inc(vResult.FalseNegatives);
    FResults.AddOrSetValue(aCorrectClass, vResult);
    if not FResults.TryGetValue(aPredictedClass, vResult) then begin
      vResult.Name := aPredictedClass;
    end;
    Inc(vResult.FalsePositives);
    FResults.AddOrSetValue(aPredictedClass, vResult);
  end;
end;

{ TAIClassificationModelNaive }

destructor TAIClassificationModelNaive.Destroy;
begin
  FModel.Free;
  inherited;
end;

function TAIClassificationModelNaive.ToJSONObject: TJSONObject;
begin
  if FModel <> nil then begin
    Result := FModel.ToJSONObject;
  end else begin
    Result := nil;
  end;
end;

destructor TAIRegressionModelLinear.Destroy;
begin
  FModel.Free;
  inherited;
end;

function TAIRegressionModelLinear.ToJSONObject: TJSONObject;
begin
  if FModel <> nil then begin
    Result := FModel.ToJSON;
  end else begin
    Result := nil;
  end;
end;

destructor TAIRegressionModelRidge.Destroy;
begin
  FModel.Free;
  inherited;
end;

function TAIRegressionModelRidge.ToJSONObject: TJSONObject;
begin
  if FModel <> nil then begin
    Result := FModel.ToJSON;
  end else begin
    Result := nil;
  end;
end;

{ TAIRecommendationModel }

constructor TAIRecommendationModel.Create(aItemsToRecommendCount, aK: Integer;
  aAggregMethod: TUserScoreAggregationMethod; aDistanceMethod: TDistanceMode; aItem : Boolean);
begin
  FItemsToRecommendCount := aItemsToRecommendCount;
  FK := aK;
  FAggregationMode := aAggregMethod;
  FDistanceMethod := aDistanceMethod;
  FItem := aItem;
end;

destructor TAIRecommendationModel.Destroy;
begin
  FModel.Free;
  inherited;
end;

function TAIRecommendationModel.ToJSONObject: TJSONObject;
begin
  Result := nil;
end;

{ TAIRecommendationSelector }

constructor TAIRecommendationSelector.Create(aDataset: TAIDatasetRecommendation;
  aNormalizationRange: TNormalizationRange);
begin
  FDataset := Copy(aDataset);
  FNormalizationRange := aNormalizationRange;
  if Length(FDataset) = 0 then begin
    raise Exception.Create('Dataset is empty.');
  end;
  FModels := TAIRecommendationModels.Create;
end;

constructor TAIRecommendationSelector.Create(aDataset: String;
  aHasHeader: Boolean);
begin
  LoadDataset(aDataset, FDataset, FNormalizationRange, aHasHeader);
  if Length(FDataset) = 0 then begin
    raise Exception.Create('Dataset is empty.');
  end;
  FModels := TAIRecommendationModels.Create;
end;

constructor TAIRecommendationSelector.Create(aDataset: TDataSet);
begin
  if aDataset.RecordCount = 0 then begin
    raise Exception.Create('Dataset is empty.');
  end;
  LoadDataset(aDataset, FDataset, FNormalizationRange);
  FModels := TAIRecommendationModels.Create;
end;

destructor TAIRecommendationSelector.Destroy;
begin
  FModels.Free;
  inherited;
end;

function SplitDatasetRec(Percentual: Double; MatrixRecommendation: TArray<TArray<Double>>): TArray<TArray<Integer>>;
var
  vNumUsers, vNumItems, vNumTestItems, i, j, Index: Integer;
  vItemsConsumed, vItemsTestUsers: TArray<Integer>;
begin
  vNumUsers := Length(MatrixRecommendation);
  SetLength(Result, vNumUsers);

  for i := 0 to vNumUsers - 1 do begin
    vNumItems := Length(MatrixRecommendation[i]);

    vItemsConsumed := [];
    for j := 0 to vNumItems - 1 do begin
      if MatrixRecommendation[i][j] > 0 then begin
        SetLength(vItemsConsumed, Length(vItemsConsumed) + 1);
        vItemsConsumed[High(vItemsConsumed)] := j;
      end;
    end;
    if Length(vItemsConsumed) > 1 then begin
      vNumTestItems := Ceil(Length(vItemsConsumed) * Percentual / 100);
      if vNumTestItems < 1 then
        vNumTestItems := 1;
    end else begin
      vNumTestItems := 0;
    end;

    SetLength(vItemsTestUsers, vNumTestItems);

    for j := 0 to vNumTestItems - 1 do
    begin
      Index := Random(Length(vItemsConsumed));

      vItemsTestUsers[j] := vItemsConsumed[Index];

      vItemsConsumed[Index] := vItemsConsumed[High(vItemsConsumed)];
      SetLength(vItemsConsumed, Length(vItemsConsumed) - 1);
    end;

    Result[i] := vItemsTestUsers;
  end;
end;

procedure TAIRecommendationSelector.RunTestsUserUser(aCsvResultFile, aLogFile : String;
                                                     aMaxThreads : Integer = 0);
var
  vLine : String;
  i, vNextFilter : Integer;
  vLogger : TLogger;
  vCSVFile : TStringList;
  vItemsToTest :  TArray<TArray<Integer>>;
begin
  if FModels.FLstModels.Count = 0 then begin
    raise Exception.Create('Add a model to test before running the tests.');
  end;
  if aMaxThreads = 0 then begin
    aMaxThreads := PCThreadCount;
  end else begin
    aMaxThreads := Min(aMaxThreads, PCThreadCount);
  end;
  vLogger := TLogger.Create(aLogFile);
  vCSVFile := TStringList.Create;
  vItemsToTest := SplitDatasetRec(25, FDataset);
  vNextFilter := 0;
  try
    while vNextFilter < FModels.FLstModels.Count do begin
      if vNextFilter + aMaxThreads > FModels.FLstModels.Count then begin
        aMaxThreads := FModels.FLstModels.Count - vNextFilter;
      end;
      TParallel.For(vNextFilter, vNextFilter + aMaxThreads - 1,
        procedure(i: Integer)
        var
          vParameters : String;
          vModel : TAIRecommendationModel;
        begin
          if not FModels.FLstModels[i].FItem then begin
            vModel := FModels.FLstModels[i];
            vParameters := ' model "Recommender User-User".';
            vLogger.Log('Starting' + vParameters);
            if vModel.Model <> nil then begin
              vModel.Model.Free;
            end;
            vModel.Model := TRecommender.Create(FDataset, FNormalizationRange, vModel.FItemsToRecommendCount,
                             vModel.FK, vModel.FAggregationMode, vModel.FDistanceMethod, False);
            vModel.Model.CalculateUserRecall(vModel.FAccurary, vItemsToTest);
            vLogger.Log('Finish' + vParameters + #13#10 +
                        'Accuracy: ' + FormatFloat('##0.000', vModel.Accuracy));
            vModel.Model.ClearDataset;
          end;
        end
      );
    vNextFilter := vNextFilter + aMaxThreads;
    end;

    if aCsvResultFile <> '' then begin
      vLine := 'ItemsToRecommend,K,AggregationMethod,DistanceMethod,Accuracy';

      vCSVFile.Add(vLine);

      for i := 0 to FModels.FLstModels.Count-1 do begin
        if not FModels.FLstModels[i].FItem then begin
          vLine := IntToStr(FModels.FLstModels[i].FItemsToRecommendCount) + ',' +
                    IntToStr(FModels.FLstModels[i].FK) + ',' +
                    AggregModeToStr(FModels.FLstModels[i].FAggregationMode) + ',' +
                    DistanceMethodToStr(FModels.FLstModels[i].FDistanceMethod) + ',' +
                    StringReplace(FormatFloat('##0.000', FModels.FLstModels[i].Accuracy), ',', '.', []);

          vCSVFile.Add(vLine);
        end;
      end;
      vCSVFile.SaveToFile(aCsvResultFile);
    end;
  finally
    vLogger.Free;
    vCSVFile.Free;
  end;
end;

procedure TAIRecommendationSelector.RunTestsItemItem(aCsvResultFile, aLogFile : String;
                                                     aMaxThreads : Integer = 0);
var
  vLine : String;
  i, vNextFilter : Integer;
  vLogger : TLogger;
  vCSVFile : TStringList;
begin
  if FModels.FLstModels.Count = 0 then begin
    raise Exception.Create('Add a model to test before running the tests.');
  end;
  if aMaxThreads = 0 then begin
    aMaxThreads := PCThreadCount;
  end else begin
    aMaxThreads := Min(aMaxThreads, PCThreadCount);
  end;
  vLogger := TLogger.Create(aLogFile);
  vCSVFile := TStringList.Create;
  vNextFilter := 0;
  try
    while vNextFilter < FModels.FLstModels.Count do begin
      if vNextFilter + aMaxThreads > FModels.FLstModels.Count then begin
        aMaxThreads := FModels.FLstModels.Count - vNextFilter;
      end;
      TParallel.For(vNextFilter, vNextFilter + aMaxThreads - 1,
        procedure(i: Integer)
        var
          vParameters : String;
          vModel : TAIRecommendationModel;
        begin
          if FModels.FLstModels[i].FItem then begin
            vModel := FModels.FLstModels[i];
            vParameters := ' model "Recommender Item-Item".';
            vLogger.Log('Starting' + vParameters);
            if vModel.Model <> nil then begin
              vModel.Model.Free;
            end;
            vModel.Model := TRecommender.Create(FDataset, FNormalizationRange, vModel.FItemsToRecommendCount,
                             vModel.FK, vModel.FAggregationMode, vModel.FDistanceMethod, False);
            vModel.Model.CalculateItemRecall(vModel.FAccurary);
            vLogger.Log('Finish' + vParameters + #13#10 +
                        'Accuracy: ' + FormatFloat('##0.000', vModel.Accuracy));
            vModel.Model.ClearDataset;
          end;
        end
      );
    vNextFilter := vNextFilter + aMaxThreads;
    end;

    if aCsvResultFile <> '' then begin
      vLine := 'ItemsToRecommend,K,DistanceMethod,Accuracy';

      vCSVFile.Add(vLine);

      for i := 0 to FModels.FLstModels.Count-1 do begin
        if FModels.FLstModels[i].FItem then begin
          vLine := IntToStr(FModels.FLstModels[i].FItemsToRecommendCount) + ',' +
                    IntToStr(FModels.FLstModels[i].FK) + ',' +
                    DistanceMethodToStr(FModels.FLstModels[i].FDistanceMethod) + ',' +
                    StringReplace(FormatFloat('##0.000', FModels.FLstModels[i].Accuracy), ',', '.', []);

          vCSVFile.Add(vLine);
        end;
      end;
      vCSVFile.SaveToFile(aCsvResultFile);
    end;
  finally
    vLogger.Free;
    vCSVFile.Free;
  end;
end;

{ TAIRecommendationModels }

procedure TAIRecommendationModels.AddItemItem(aItemsToRecommendCount : Integer; aDistanceMethod: TDistanceMode);
begin
  FLstModels.Add(TAIRecommendationModel.Create(aItemsToRecommendCount, 0, amMode, aDistanceMethod, True));
end;

procedure TAIRecommendationModels.AddUserUser(aItemsToRecommendCount, aK: Integer; aAggregMethod: TUserScoreAggregationMethod; aDistanceMethod: TDistanceMode);
begin
  FLstModels.Add(TAIRecommendationModel.Create(aItemsToRecommendCount, aK, aAggregMethod, aDistanceMethod, False));
end;

constructor TAIRecommendationModels.Create;
begin
  FLstModels := TList<TAIRecommendationModel>.Create;
end;

destructor TAIRecommendationModels.Destroy;
var
  i : Integer;
begin
  for i := 0 to FLstModels.Count-1 do begin
    FLstModels[i].Free;
  end;
  FLstModels.Free;
  inherited;
end;

{ TAIRegressionTest }

constructor TAIRegressionTest.Create;
begin
  FFinished := False;
  FSumSquaredErrors := 0;
  FSumAbsoluteErrors := 0;
  FSumCorrectValues := 0;
  FSampleCount := 0;
  FMAE := 0;
  FMSE := 0;
  FRMSE := 0;
  FR2 := 0;
  FCorrectValues := TList<Double>.Create;
end;

procedure TAIRegressionTest.ProcessResult(aPredictedValue, aCorrectValue: Double);
var
  vError, vSquaredError: Double;
begin
  Inc(FSampleCount);

  vError := aPredictedValue - aCorrectValue;
  vSquaredError := Sqr(vError);

  FSumSquaredErrors := FSumSquaredErrors + vSquaredError;
  FSumAbsoluteErrors := FSumAbsoluteErrors + Abs(vError);
  FSumCorrectValues := FSumCorrectValues + aCorrectValue;

  FCorrectValues.Add(aCorrectValue);
end;

destructor TAIClassificationModelKNN.Destroy;
begin
  FModel.Free;
  inherited;
end;

end.
