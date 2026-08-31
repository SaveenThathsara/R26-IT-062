import 'dart:math';

/// Feature engineering — exact replication of engineer_features_single()
/// from the notebook (Section 2).
///
/// IMPORTANT: The feature ORDER here matches feature_columns.json exactly:
/// ['Soil_Moisture','Temperature','Humidity','N','P','K','Soil_pH','Rainfall',
///  'Moisture_x_Rain','Moisture_x_Humid','NPK_sum','NPK_product','Temp_x_Humid',
///  'Rain_x_Humid','pH_x_NPK','Moisture_sq','Rain_sq','log_Rain','log_NPK',
///  'N_to_P','Moisture_to_Rain','optimal_moisture','optimal_temp',
///  'optimal_pH','optimal_rain']
class BetelFeatureEngineering {

  /// 8 raw input feature names (user fills these)
  static const List<String> baseFeatureNames = [
    'Soil_Moisture',
    'Rainfall',
    'Humidity',
    'N',
    'P',
    'K',
    'Temperature',
    'Soil_pH',
  ];

  /// 25 engineered feature names in EXACT order of feature_columns.json
  /// This order is what the ONNX model expects as float_input[1,25]
  static const List<String> allFeatureNames = [
    'Soil_Moisture',      // 0
    'Temperature',        // 1  ← NOTE: Temperature is index 1, not 6
    'Humidity',           // 2
    'N',                  // 3
    'P',                  // 4
    'K',                  // 5
    'Soil_pH',            // 6  ← NOTE: Soil_pH is index 6
    'Rainfall',           // 7  ← NOTE: Rainfall is index 7
    'Moisture_x_Rain',    // 8
    'Moisture_x_Humid',   // 9
    'NPK_sum',            // 10
    'NPK_product',        // 11
    'Temp_x_Humid',       // 12
    'Rain_x_Humid',       // 13
    'pH_x_NPK',           // 14
    'Moisture_sq',        // 15
    'Rain_sq',            // 16
    'log_Rain',           // 17  np.log1p(Rainfall)
    'log_NPK',            // 18  np.log1p(NPK_sum)
    'N_to_P',             // 19  N / (P + 1e-6)
    'Moisture_to_Rain',   // 20  SM / (Rain + 1e-6)
    'optimal_moisture',   // 21  int(55 <= SM <= 75)
    'optimal_temp',       // 22  int(25 <= Temp <= 32)
    'optimal_pH',         // 23  int(5.5 <= pH <= 7.0)
    'optimal_rain',       // 24  int(150 <= Rain <= 300)
  ];

  static const Map<String, Map<String, double>> inputBounds = {
    'Soil_Moisture': {'min': 0,   'max': 100},
    'Rainfall':      {'min': 0,   'max': 500},
    'Humidity':      {'min': 0,   'max': 100},
    'N':             {'min': 0,   'max': 200},
    'P':             {'min': 0,   'max': 200},
    'K':             {'min': 0,   'max': 200},
    'Temperature':   {'min': 10,  'max': 45},
    'Soil_pH':       {'min': 3.0, 'max': 9.0},
  };

  static const Map<String, String> inputRanges = {
    'Soil_Moisture': '0 – 100 (%)',
    'Rainfall':      '0 – 500 (mm)',
    'Humidity':      '0 – 100 (%)',
    'N':             '0 – 200 (kg/ha)',
    'P':             '0 – 200 (kg/ha)',
    'K':             '0 – 200 (kg/ha)',
    'Temperature':   '10 – 45 (°C)',
    'Soil_pH':       '3.0 – 9.0',
  };

  static const Map<String, String> featureUnits = {
    'Soil_Moisture': '%',
    'Rainfall':      'mm',
    'Humidity':      '%',
    'N':             'kg/ha',
    'P':             'kg/ha',
    'K':             'kg/ha',
    'Temperature':   '°C',
    'Soil_pH':       'pH',
  };

  static const Map<String, String> featureIcons = {
    'Soil_Moisture': '💧',
    'Rainfall':      '🌧️',
    'Humidity':      '🌫️',
    'N':             '🧪',
    'P':             '⚗️',
    'K':             '🔬',
    'Temperature':   '🌡️',
    'Soil_pH':       '🧫',
  };

  static const Map<String, String> featureDescriptions = {
    'Soil_Moisture': 'Soil Water Content',
    'Rainfall':      'Monthly Rainfall',
    'Humidity':      'Relative Humidity',
    'N':             'Nitrogen Content',
    'P':             'Phosphorus Content',
    'K':             'Potassium Content',
    'Temperature':   'Air Temperature',
    'Soil_pH':       'Soil pH Level',
  };

  /// Builds the 25-element float32 feature vector in EXACT feature_columns.json order.
  /// This is what gets passed as float_input to the ONNX model.
  ///
  /// Mirrors engineer_features_single() from notebook Section 2:
  ///   sm*rain, sm*hum, N+P+K, N*P*K, temp*hum, rain*hum, pH*(N+P+K),
  ///   sm^2, rain^2, log1p(rain), log1p(NPK_sum),
  ///   N/(P+1e-6), sm/(rain+1e-6),
  ///   int(55<=sm<=75), int(25<=t<=32), int(5.5<=pH<=7.0), int(150<=rain<=300)
  static List<double> engineerFeatures(Map<String, double> inputs) {
    final double sm   = inputs['Soil_Moisture']!;
    final double temp = inputs['Temperature']!;
    final double hum  = inputs['Humidity']!;
    final double n    = inputs['N']!;
    final double p    = inputs['P']!;
    final double k    = inputs['K']!;
    final double ph   = inputs['Soil_pH']!;
    final double rain = inputs['Rainfall']!;

    final double npkSum     = n + p + k;
    final double npkProduct = n * p * k;

    return [
      sm,                                            // 0  Soil_Moisture
      temp,                                          // 1  Temperature
      hum,                                           // 2  Humidity
      n,                                             // 3  N
      p,                                             // 4  P
      k,                                             // 5  K
      ph,                                            // 6  Soil_pH
      rain,                                          // 7  Rainfall
      sm * rain,                                     // 8  Moisture_x_Rain
      sm * hum,                                      // 9  Moisture_x_Humid
      npkSum,                                        // 10 NPK_sum
      npkProduct,                                    // 11 NPK_product
      temp * hum,                                    // 12 Temp_x_Humid
      rain * hum,                                    // 13 Rain_x_Humid
      ph * npkSum,                                   // 14 pH_x_NPK
      sm * sm,                                       // 15 Moisture_sq
      rain * rain,                                   // 16 Rain_sq
      log(1.0 + rain),                               // 17 log_Rain  (np.log1p)
      log(1.0 + npkSum),                             // 18 log_NPK   (np.log1p)
      n / (p + 1e-6),                                // 19 N_to_P
      sm / (rain + 1e-6),                            // 20 Moisture_to_Rain
      (sm >= 55 && sm <= 75)     ? 1.0 : 0.0,        // 21 optimal_moisture
      (temp >= 25 && temp <= 32) ? 1.0 : 0.0,        // 22 optimal_temp
      (ph >= 5.5 && ph <= 7.0)   ? 1.0 : 0.0,        // 23 optimal_pH
      (rain >= 150 && rain <= 300) ? 1.0 : 0.0,      // 24 optimal_rain
    ];
  }

  /// Returns map of feature name → value (for display)
  static Map<String, double> getEngineeredValues(Map<String, double> inputs) {
    final values = engineerFeatures(inputs);
    return { for (int i = 0; i < allFeatureNames.length; i++) allFeatureNames[i]: values[i] };
  }

  /// Returns which optimal conditions are met
  static Map<String, bool> getOptimalConditions(Map<String, double> inputs) {
    return {
      'optimal_moisture': inputs['Soil_Moisture']! >= 55 && inputs['Soil_Moisture']! <= 75,
      'optimal_temp':     inputs['Temperature']!   >= 25 && inputs['Temperature']!   <= 32,
      'optimal_pH':       inputs['Soil_pH']!       >= 5.5 && inputs['Soil_pH']!      <= 7.0,
      'optimal_rain':     inputs['Rainfall']!      >= 150 && inputs['Rainfall']!     <= 300,
    };
  }
}
