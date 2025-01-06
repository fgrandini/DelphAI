object FDelphAIExamples: TFDelphAIExamples
  Left = 0
  Top = 0
  Caption = 'DelphAI Examples'
  ClientHeight = 344
  ClientWidth = 871
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -12
  Font.Name = 'Segoe UI'
  Font.Style = []
  TextHeight = 15
  object gbEasy: TGroupBox
    Left = 17
    Top = 8
    Width = 297
    Height = 329
    Caption = 'EasyAI'
    TabOrder = 0
    object gbClassification: TGroupBox
      Left = 8
      Top = 87
      Width = 275
      Height = 89
      Caption = 'Classification'
      TabOrder = 0
      object Button1: TButton
        Left = 13
        Top = 24
        Width = 139
        Height = 25
        Caption = 'Generate Iris model'
        TabOrder = 0
        OnClick = Button1Click
      end
      object Button2: TButton
        Left = 158
        Top = 24
        Width = 103
        Height = 25
        Caption = 'Use Iris model'
        TabOrder = 1
        OnClick = Button2Click
      end
      object Button10: TButton
        Left = 13
        Top = 55
        Width = 139
        Height = 25
        Caption = 'Generate cancer model'
        TabOrder = 2
        OnClick = Button10Click
      end
      object Button12: TButton
        Left = 158
        Top = 55
        Width = 103
        Height = 25
        Caption = 'Use cancer model'
        TabOrder = 3
        OnClick = Button12Click
      end
    end
    object gbReg: TGroupBox
      Left = 8
      Top = 18
      Width = 275
      Height = 65
      Caption = 'Regression'
      TabOrder = 1
      object Button3: TButton
        Left = 16
        Top = 24
        Width = 136
        Height = 25
        Caption = 'Generate model'
        TabOrder = 0
        OnClick = Button3Click
      end
      object Button4: TButton
        Left = 158
        Top = 24
        Width = 89
        Height = 25
        Caption = 'Use model'
        TabOrder = 1
        OnClick = Button4Click
      end
    end
    object GroupBox1: TGroupBox
      Left = 8
      Top = 180
      Width = 275
      Height = 65
      Caption = 'Recommend by item'
      TabOrder = 2
      object Button5: TButton
        Left = 16
        Top = 24
        Width = 136
        Height = 25
        Caption = 'Generate model'
        TabOrder = 0
        OnClick = Button5Click
      end
      object Button6: TButton
        Left = 158
        Top = 24
        Width = 89
        Height = 25
        Caption = 'Use model'
        TabOrder = 1
        OnClick = Button6Click
      end
    end
    object GroupBox2: TGroupBox
      Left = 8
      Top = 249
      Width = 275
      Height = 65
      Caption = 'Recommend by user'
      TabOrder = 3
      object Button7: TButton
        Left = 16
        Top = 24
        Width = 136
        Height = 25
        Caption = 'Generate model'
        TabOrder = 0
        OnClick = Button7Click
      end
      object Button8: TButton
        Left = 158
        Top = 24
        Width = 89
        Height = 25
        Caption = 'Use model'
        TabOrder = 1
        OnClick = Button8Click
      end
    end
  end
  object GroupBox3: TGroupBox
    Left = 344
    Top = 8
    Width = 169
    Height = 328
    Caption = 'Selector'
    TabOrder = 1
    object GroupBox4: TGroupBox
      Left = 16
      Top = 87
      Width = 133
      Height = 65
      Caption = 'Classification'
      TabOrder = 0
      object Button9: TButton
        Left = 16
        Top = 24
        Width = 97
        Height = 25
        Caption = 'Test models'
        TabOrder = 0
        OnClick = Button9Click
      end
    end
    object GroupBox5: TGroupBox
      Left = 16
      Top = 18
      Width = 133
      Height = 65
      Caption = 'Regression'
      TabOrder = 1
      object Button11: TButton
        Left = 16
        Top = 24
        Width = 97
        Height = 25
        Caption = 'Test models'
        TabOrder = 0
        OnClick = Button11Click
      end
    end
    object GroupBox6: TGroupBox
      Left = 16
      Top = 156
      Width = 133
      Height = 65
      Caption = 'Recommend by item'
      TabOrder = 2
      object Button13: TButton
        Left = 16
        Top = 24
        Width = 97
        Height = 25
        Caption = 'Test models'
        TabOrder = 0
        OnClick = Button13Click
      end
    end
    object GroupBox7: TGroupBox
      Left = 16
      Top = 225
      Width = 133
      Height = 65
      Caption = 'Recommend by user'
      TabOrder = 3
      object Button15: TButton
        Left = 16
        Top = 24
        Width = 97
        Height = 25
        Caption = 'Test models'
        TabOrder = 0
        OnClick = Button15Click
      end
    end
  end
  object gbClassificationModels: TGroupBox
    Left = 710
    Top = 8
    Width = 153
    Height = 121
    Caption = 'Classification Models'
    TabOrder = 2
    object Button14: TButton
      Left = 31
      Top = 24
      Width = 97
      Height = 25
      Caption = 'KNN'
      TabOrder = 0
      OnClick = Button14Click
    end
    object Button16: TButton
      Left = 31
      Top = 55
      Width = 97
      Height = 25
      Caption = 'Tree Decision'
      TabOrder = 1
      OnClick = Button16Click
    end
    object Button17: TButton
      Left = 31
      Top = 86
      Width = 97
      Height = 25
      Caption = 'Naive Bayes'
      TabOrder = 2
      OnClick = Button17Click
    end
  end
  object GroupBox8: TGroupBox
    Left = 541
    Top = 8
    Width = 153
    Height = 121
    Caption = 'Regression Models'
    TabOrder = 3
    object Button18: TButton
      Left = 29
      Top = 24
      Width = 99
      Height = 25
      Caption = 'KNN'
      TabOrder = 0
      OnClick = Button18Click
    end
    object Button19: TButton
      Left = 29
      Top = 55
      Width = 101
      Height = 25
      Caption = 'Linear Regression'
      TabOrder = 1
      OnClick = Button19Click
    end
    object Button20: TButton
      Left = 29
      Top = 86
      Width = 99
      Height = 25
      Caption = 'Ridge Regression'
      TabOrder = 2
      OnClick = Button20Click
    end
  end
  object GroupBox9: TGroupBox
    Left = 710
    Top = 135
    Width = 153
    Height = 121
    Caption = 'Clustering Models'
    TabOrder = 4
    object Button21: TButton
      Left = 31
      Top = 24
      Width = 97
      Height = 25
      Caption = 'KMeans'
      TabOrder = 0
      OnClick = Button21Click
    end
    object Button22: TButton
      Left = 31
      Top = 55
      Width = 97
      Height = 25
      Caption = 'Mean Shift'
      TabOrder = 1
      OnClick = Button22Click
    end
    object Button23: TButton
      Left = 31
      Top = 86
      Width = 97
      Height = 25
      Caption = 'DBSCAN'
      TabOrder = 2
      OnClick = Button23Click
    end
  end
  object GroupBox10: TGroupBox
    Left = 541
    Top = 135
    Width = 153
    Height = 57
    Caption = 'Recommendation models'
    TabOrder = 5
    object Button24: TButton
      Left = 10
      Top = 21
      Width = 134
      Height = 25
      Caption = 'Collaborative filtering'
      TabOrder = 0
      OnClick = Button24Click
    end
  end
  object Button25: TButton
    Left = 543
    Top = 262
    Width = 319
    Height = 33
    Caption = 'Open english documentation'
    TabOrder = 6
    OnClick = Button25Click
  end
  object Button26: TButton
    Left = 541
    Top = 304
    Width = 322
    Height = 33
    Caption = 'Abrir documenta'#231#227'o em portugu'#234's'
    TabOrder = 7
    OnClick = Button26Click
  end
end
