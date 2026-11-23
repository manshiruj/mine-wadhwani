import 'package:mine_wadhwani/presentation/screens/agent/risk_monitor_screen.dart';
import 'package:mine_wadhwani/core/l10n/app_language.dart';
// import 'dart:math';
// import 'package:flutter/material.dart';

// class RiskAnalysisScreen extends StatefulWidget {
//   const RiskAnalysisScreen({super.key});

//   @override
//   State<RiskAnalysisScreen> createState() => _RiskAnalysisScreenState();
// }

// class _RiskAnalysisScreenState extends State<RiskAnalysisScreen>
//     with TickerProviderStateMixin {
//   // ── Colors ──────────────────────────────────────────────────────────────────
//   static const Color primary = Color(0xFF1F579C);
//   static const Color bg = Color(0xFFF5F7FA);

//   // ── Form State ───────────────────────────────────────────────────────────────
//   final _formKey = GlobalKey<FormState>();

//   // Coal Grade: G1–G14
//   String _selectedGrade = 'G7';
//   final List<String> _grades = [
//     'G1', 'G2', 'G3',
//     'G4', 'G5', 'G6',
//     'G7', 'G8', 'G9',
//     'G10', 'G11', 'G12',
//     'G13', 'G14',
//   ];

//   final _tempController    = TextEditingController(text: '38');
//   final _rhController      = TextEditingController(text: '13');
//   final _o2Controller      = TextEditingController(text: '20.9');
//   final _coController      = TextEditingController(text: '140');
//   final _finesController   = TextEditingController(text: '15');

//   // ── Result State ─────────────────────────────────────────────────────────────
//   double _riskScore = 0;        // 0–100
//   bool   _analysed  = false;
//   bool   _loading   = false;

//   late AnimationController _needleController;
//   late Animation<double>   _needleAnimation;
//   double _previousScore = 0;

//   @override
//   void initState() {
//     super.initState();
//     _needleController = AnimationController(
//       vsync: this,
//       duration: const Duration(milliseconds: 1400),
//     );
//     _needleAnimation = Tween<double>(begin: 0, end: 0).animate(
//       CurvedAnimation(parent: _needleController, curve: Curves.easeInOutCubic),
//     );
//   }

//   @override
//   void dispose() {
//     _needleController.dispose();
//     _tempController.dispose();
//     _rhController.dispose();
//     _o2Controller.dispose();
//     _coController.dispose();
//     _finesController.dispose();
//     super.dispose();
//   }

//   // ── Coal Grade → numeric risk weight (0.1 = safest, 1.0 = most dangerous) ──
//   double _gradeToRiskWeight(String grade) {
//     const map = {
//       'G1': 0.05, 'G2': 0.08, 'G3': 0.10,
//       'G4': 0.18, 'G5': 0.22, 'G6': 0.26,
//       'G7': 0.34, 'G8': 0.38, 'G9': 0.42,
//       'G10': 0.58, 'G11': 0.64, 'G12': 0.70,
//       'G13': 0.85, 'G14': 1.00,
//     };
//     return map[grade] ?? 0.5;
//   }

//   String _gradeGroup(String grade) {
//     final n = int.tryParse(grade.replaceAll('G', '')) ?? 7;
//     if (n <= 3)  return 'G1–G3 · High-rank Bituminous · Low Tendency';
//     if (n <= 6)  return 'G4–G6 · Good Quality Bituminous · Low–Moderate';
//     if (n <= 9)  return 'G7–G9 · Medium Rank · Moderate Tendency';
//     if (n <= 12) return 'G10–G12 · Low Rank · High Tendency';
//     return 'G13–G14 · Very Low Rank / High Moisture · Very High Tendency';
//   }

//   // ── Risk Calculation ─────────────────────────────────────────────────────────
//   double _calculateRisk() {
//     final T     = double.tryParse(_tempController.text)   ?? 25.0;
//     final RH    = double.tryParse(_rhController.text)     ?? 50.0;
//     final O2    = double.tryParse(_o2Controller.text)     ?? 20.9;
//     final CO    = double.tryParse(_coController.text)     ?? 0.0;
//     final fines = double.tryParse(_finesController.text)  ?? 10.0;
//     final gw    = _gradeToRiskWeight(_selectedGrade);

//     // Normalized sensor contributions (0–1 each)
//     final tNorm     = ((T - 10)   / 50.0).clamp(0.0, 1.0);       // 10–60 °C
//     final rhNorm    = ((100 - RH) / 100.0).clamp(0.0, 1.0);      // dryness → risk
//     final o2Norm    = ((21 - O2)  / 21.0).clamp(0.0, 1.0);       // O₂ depletion
//     final coNorm    = (CO          / 500.0).clamp(0.0, 1.0);      // 0–500 ppb
//     final finesNorm = (fines       / 100.0).clamp(0.0, 1.0);

//     // Weights: Grade 35%, T 20%, RH 15%, CO 15%, O₂ 10%, Fines 5%
//     final score = (gw      * 35.0
//                  + tNorm   * 20.0
//                  + rhNorm  * 15.0
//                  + coNorm  * 15.0
//                  + o2Norm  * 10.0
//                  + finesNorm * 5.0);

//     return score.clamp(0.0, 100.0);
//   }

//   void _analyse() async {
//     if (!_formKey.currentState!.validate()) return;
//     setState(() { _loading = true; });
//     await Future.delayed(const Duration(milliseconds: 600));

//     final score = _calculateRisk();

//     _needleAnimation = Tween<double>(
//       begin: _previousScore,
//       end: score,
//     ).animate(
//       CurvedAnimation(parent: _needleController, curve: Curves.easeInOutCubic),
//     );
//     _needleController.forward(from: 0);
//     _previousScore = score;

//     setState(() {
//       _riskScore = score;
//       _analysed  = true;
//       _loading   = false;
//     });
//   }

//   // ── Risk Level Info ──────────────────────────────────────────────────────────
//   _RiskLevel _getRiskLevel(double score) {
//     if (score < 17)  return _RiskLevel('Low',              const Color(0xFF2E7D32), const Color(0xFFE8F5E9), Icons.check_circle_rounded,        'Acceptable risk. No immediate action required. Follow standard SOPs and routine monitoring.');
//     if (score < 34)  return _RiskLevel('Low to Moderate',  const Color(0xFF558B2F), const Color(0xFFF1F8E9), Icons.info_rounded,                 'Minor risk detected. Increase monitoring frequency and review coal handling procedures.');
//     if (score < 50)  return _RiskLevel('Moderate',         const Color(0xFFF9A825), const Color(0xFFFFFDE7), Icons.warning_amber_rounded,        'Tolerable risk under controlled conditions. Planned mitigation and supervision required.');
//     if (score < 67)  return _RiskLevel('Moderately High',  const Color(0xFFEF6C00), const Color(0xFFFFF3E0), Icons.warning_rounded,              'Serious risk. Active management and urgent corrective action needed. Alert safety officer.');
//     if (score < 84)  return _RiskLevel('High',             const Color(0xFFD32F2F), const Color(0xFFFFEBEE), Icons.dangerous_rounded,            'High risk of spontaneous heating. Work allowed only with strict controls. Daily monitoring mandatory.');
//     return               _RiskLevel('Very High',           const Color(0xFF7B0000), const Color(0xFFFFCDD2), Icons.local_fire_department_rounded, 'CRITICAL: Immediate threat. Halt stockpile operations. Emergency response required. Alert Mine Manager.');
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       backgroundColor: bg,
//       body: Column(
//         children: [
//           _buildTopBar(context),
//           Expanded(
//             child: SingleChildScrollView(
//               padding: const EdgeInsets.all(24),
//               child: Column(
//                 crossAxisAlignment: CrossAxisAlignment.start,
//                 children: [
//                   _buildHeader(),
//                   const SizedBox(height: 24),
//                   Row(
//                     crossAxisAlignment: CrossAxisAlignment.start,
//                     children: [
//                       // ── Left: Input Form ──────────────────────────────
//                       Expanded(flex: 4, child: _buildInputForm()),
//                       const SizedBox(width: 24),
//                       // ── Right: Riskometer + Result ────────────────────
//                       Expanded(flex: 6, child: _buildRightPanel()),
//                     ],
//                   ),
//                 ],
//               ),
//             ),
//           ),
//         ],
//       ),
//     );
//   }

//   // ── Top Bar ──────────────────────────────────────────────────────────────────
//   Widget _buildTopBar(BuildContext context) {
//     return Container(
//       color: primary,
//       padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
//       child: SafeArea(
//         bottom: false,
//         child: Row(
//           children: [
//             IconButton(
//               icon: const Icon(Icons.arrow_back_ios_new_rounded,
//                   color: Colors.white, size: 18),
//               onPressed: () => Navigator.of(context).pop(),
//             ),
//             const SizedBox(width: 8),
//             Column(
//               crossAxisAlignment: CrossAxisAlignment.start,
//               children: const [
//                 Text('AIMSURE',
//                     style: TextStyle(
//                         color: Colors.white,
//                         fontWeight: FontWeight.w900,
//                         fontSize: 17,
//                         letterSpacing: 1.2)),
//                 Text('Mine Safety Solution',
//                     style: TextStyle(color: Colors.white54, fontSize: 10)),
//               ],
//             ),
//             const SizedBox(width: 16),
//             Container(width: 1, height: 36, color: Colors.white24),
//             const SizedBox(width: 16),
//             const Text(
//               'Risk Analysis',
//               style: TextStyle(
//                   color: Colors.white,
//                   fontSize: 16,
//                   fontWeight: FontWeight.w700),
//             ),
//             const Spacer(),
//             Container(
//               padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
//               decoration: BoxDecoration(
//                 color: Colors.white12,
//                 borderRadius: BorderRadius.circular(20),
//                 border: Border.all(color: Colors.white24, width: 0.8),
//               ),
//               child: Row(children: const [
//                 Icon(Icons.query_stats_rounded,
//                     color: Colors.white70, size: 14),
//                 SizedBox(width: 6),
//                 Text('Spontaneous Heating Index',
//                     style: TextStyle(color: Colors.white70, fontSize: 11)),
//               ]),
//             ),
//           ],
//         ),
//       ),
//     );
//   }

//   // ── Page Header ──────────────────────────────────────────────────────────────
//   Widget _buildHeader() {
//     return Row(
//       children: [
//         Container(
//           width: 4, height: 48,
//           decoration: BoxDecoration(
//               color: primary, borderRadius: BorderRadius.circular(4)),
//         ),
//         const SizedBox(width: 12),
//         Column(
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             const Text('Stockpile Risk Analysis',
//                 style: TextStyle(
//                     fontSize: 22,
//                     fontWeight: FontWeight.w800,
//                     color: primary,
//                     height: 1.1)),
//             const SizedBox(height: 4),
//             Text('Enter sensor readings to compute spontaneous heating risk index',
//                 style: TextStyle(fontSize: 12, color: Colors.grey[500])),
//           ],
//         ),
//         const Spacer(),
//         // Formula chip
//         Container(
//           padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
//           decoration: BoxDecoration(
//             color: const Color(0xFFE8F0FB),
//             borderRadius: BorderRadius.circular(8),
//             border: Border.all(color: primary.withValues(alpha: 0.2)),
//           ),
//           child: Row(children: [
//             const Icon(Icons.functions_rounded, color: primary, size: 15),
//             const SizedBox(width: 6),
//             Text('Risk ∝ 1/Grade + f(T, RH, O₂, CO, Fines)',
//                 style: const TextStyle(
//                     fontSize: 11,
//                     color: primary,
//                     fontWeight: FontWeight.w600,
//                     fontFamily: 'monospace')),
//           ]),
//         ),
//       ],
//     );
//   }

//   // ── Input Form ───────────────────────────────────────────────────────────────
//   Widget _buildInputForm() {
//     return Container(
//       decoration: BoxDecoration(
//         color: Colors.white,
//         borderRadius: BorderRadius.circular(12),
//         border: Border.all(color: Colors.grey.shade200),
//         boxShadow: [
//           BoxShadow(
//               color: Colors.grey.withValues(alpha: 0.07),
//               blurRadius: 10,
//               offset: const Offset(0, 3))
//         ],
//       ),
//       child: Form(
//         key: _formKey,
//         child: Column(
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             // Form header
//             Container(
//               padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
//               decoration: BoxDecoration(
//                 color: const Color(0xFFF5F7FA),
//                 borderRadius:
//                     const BorderRadius.vertical(top: Radius.circular(12)),
//                 border: Border(
//                     bottom: BorderSide(color: Colors.grey.shade200)),
//               ),
//               child: Row(children: [
//                 Container(
//                   padding: const EdgeInsets.all(7),
//                   decoration: BoxDecoration(
//                       color: const Color(0xFFE8F0FB),
//                       borderRadius: BorderRadius.circular(8)),
//                   child: const Icon(Icons.sensors_rounded,
//                       color: primary, size: 16),
//                 ),
//                 const SizedBox(width: 10),
//                 const Text('Sensor Parameters',
//                     style: TextStyle(
//                         fontWeight: FontWeight.w700,
//                         fontSize: 14,
//                         color: Color(0xFF1A1A2E))),
//               ]),
//             ),

//             Padding(
//               padding: const EdgeInsets.all(20),
//               child: Column(
//                 children: [
//                   // Coal Grade
//                   _buildGradeDropdown(),
//                   const SizedBox(height: 16),
//                   _buildInputField(
//                     controller: _tempController,
//                     label: 'Temperature',
//                     unit: '°C',
//                     hint: '25–60',
//                     icon: Icons.thermostat_rounded,
//                     iconColor: const Color(0xFFE53935),
//                     validator: (v) {
//                       final val = double.tryParse(v ?? '');
//                       if (val == null) return 'Enter valid number';
//                       if (val < -10 || val > 100) return '–10 to 100 °C';
//                       return null;
//                     },
//                   ),
//                   const SizedBox(height: 16),
//                   _buildInputField(
//                     controller: _rhController,
//                     label: 'Relative Humidity',
//                     unit: '%',
//                     hint: '0–100',
//                     icon: Icons.water_drop_rounded,
//                     iconColor: const Color(0xFF1E88E5),
//                     validator: (v) {
//                       final val = double.tryParse(v ?? '');
//                       if (val == null) return 'Enter valid number';
//                       if (val < 0 || val > 100) return '0 to 100 %';
//                       return null;
//                     },
//                   ),
//                   const SizedBox(height: 16),
//                   _buildInputField(
//                     controller: _o2Controller,
//                     label: 'Oxygen (O₂)',
//                     unit: '%',
//                     hint: '0–21',
//                     icon: Icons.air_rounded,
//                     iconColor: const Color(0xFF43A047),
//                     validator: (v) {
//                       final val = double.tryParse(v ?? '');
//                       if (val == null) return 'Enter valid number';
//                       if (val < 0 || val > 21) return '0 to 21 %';
//                       return null;
//                     },
//                   ),
//                   const SizedBox(height: 16),
//                   _buildInputField(
//                     controller: _coController,
//                     label: 'Carbon Monoxide (CO)',
//                     unit: 'ppb',
//                     hint: '0–500',
//                     icon: Icons.cloud_rounded,
//                     iconColor: const Color(0xFF6D4C41),
//                     validator: (v) {
//                       final val = double.tryParse(v ?? '');
//                       if (val == null) return 'Enter valid number';
//                       if (val < 0) return 'Must be ≥ 0';
//                       return null;
//                     },
//                   ),
//                   const SizedBox(height: 16),
//                   _buildInputField(
//                     controller: _finesController,
//                     label: 'Coal Fines',
//                     unit: '%',
//                     hint: '0–100',
//                     icon: Icons.grain_rounded,
//                     iconColor: const Color(0xFF8D6E63),
//                     validator: (v) {
//                       final val = double.tryParse(v ?? '');
//                       if (val == null) return 'Enter valid number';
//                       if (val < 0 || val > 100) return '0 to 100 %';
//                       return null;
//                     },
//                   ),
//                   const SizedBox(height: 24),
//                   // Analyse Button
//                   SizedBox(
//                     width: double.infinity,
//                     child: ElevatedButton.icon(
//                       onPressed: _loading ? null : _analyse,
//                       icon: _loading
//                           ? const SizedBox(
//                               width: 16,
//                               height: 16,
//                               child: CircularProgressIndicator(
//                                   strokeWidth: 2, color: Colors.white))
//                           : const Icon(Icons.analytics_rounded, size: 18),
//                       label: Text(
//                         _loading ? 'Analysing...' : 'Analyse Risk',
//                         style: const TextStyle(
//                             fontWeight: FontWeight.w700, fontSize: 15),
//                       ),
//                       style: ElevatedButton.styleFrom(
//                         backgroundColor: primary,
//                         foregroundColor: Colors.white,
//                         padding: const EdgeInsets.symmetric(vertical: 14),
//                         shape: RoundedRectangleBorder(
//                             borderRadius: BorderRadius.circular(10)),
//                         elevation: 0,
//                       ),
//                     ),
//                   ),
//                 ],
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }

//   Widget _buildGradeDropdown() {
//     return Column(
//       crossAxisAlignment: CrossAxisAlignment.start,
//       children: [
//         Row(children: [
//           Container(
//             padding: const EdgeInsets.all(6),
//             decoration: BoxDecoration(
//                 color: const Color(0xFFFFF3E0),
//                 borderRadius: BorderRadius.circular(6)),
//             child: const Icon(Icons.layers_rounded,
//                 color: Color(0xFFEF6C00), size: 15),
//           ),
//           const SizedBox(width: 8),
//           const Text('Coal Grade',
//               style: TextStyle(
//                   fontSize: 13,
//                   fontWeight: FontWeight.w600,
//                   color: Color(0xFF1A1A2E))),
//         ]),
//         const SizedBox(height: 8),
//         DropdownButtonFormField<String>(
//           value: _selectedGrade,
//           decoration: InputDecoration(
//             contentPadding:
//                 const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
//             border: OutlineInputBorder(
//                 borderRadius: BorderRadius.circular(8),
//                 borderSide: BorderSide(color: Colors.grey.shade300)),
//             enabledBorder: OutlineInputBorder(
//                 borderRadius: BorderRadius.circular(8),
//                 borderSide: BorderSide(color: Colors.grey.shade300)),
//             focusedBorder: OutlineInputBorder(
//                 borderRadius: BorderRadius.circular(8),
//                 borderSide: const BorderSide(color: primary, width: 1.5)),
//             filled: true,
//             fillColor: const Color(0xFFFAFAFA),
//           ),
//           items: _grades
//               .map((g) => DropdownMenuItem(
//                     value: g,
//                     child: Text('$g  ·  ${_gradeHint(g)}',
//                         style: const TextStyle(fontSize: 13)),
//                   ))
//               .toList(),
//           onChanged: (v) => setState(() => _selectedGrade = v!),
//         ),
//         const SizedBox(height: 4),
//         Text(_gradeGroup(_selectedGrade),
//             style: TextStyle(fontSize: 11, color: Colors.grey[500])),
//       ],
//     );
//   }

//   String _gradeHint(String g) {
//     final n = int.tryParse(g.replaceAll('G', '')) ?? 7;
//     if (n <= 3)  return '>6200 kcal/kg';
//     if (n <= 6)  return '5600–6200 kcal/kg';
//     if (n <= 9)  return '4900–5600 kcal/kg';
//     if (n <= 12) return '3400–4900 kcal/kg';
//     return '<3400 kcal/kg';
//   }

//   Widget _buildInputField({
//     required TextEditingController controller,
//     required String label,
//     required String unit,
//     required String hint,
//     required IconData icon,
//     required Color iconColor,
//     String? Function(String?)? validator,
//   }) {
//     return Column(
//       crossAxisAlignment: CrossAxisAlignment.start,
//       children: [
//         Row(children: [
//           Container(
//             padding: const EdgeInsets.all(6),
//             decoration: BoxDecoration(
//                 color: iconColor.withValues(alpha: 0.1),
//                 borderRadius: BorderRadius.circular(6)),
//             child: Icon(icon, color: iconColor, size: 15),
//           ),
//           const SizedBox(width: 8),
//           Text(label,
//               style: const TextStyle(
//                   fontSize: 13,
//                   fontWeight: FontWeight.w600,
//                   color: Color(0xFF1A1A2E))),
//         ]),
//         const SizedBox(height: 8),
//         TextFormField(
//           controller: controller,
//           keyboardType:
//               const TextInputType.numberWithOptions(decimal: true),
//           validator: validator,
//           style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
//           decoration: InputDecoration(
//             hintText: hint,
//             suffixText: unit,
//             suffixStyle: TextStyle(
//                 color: Colors.grey[500],
//                 fontSize: 13,
//                 fontWeight: FontWeight.w500),
//             contentPadding:
//                 const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
//             border: OutlineInputBorder(
//                 borderRadius: BorderRadius.circular(8),
//                 borderSide: BorderSide(color: Colors.grey.shade300)),
//             enabledBorder: OutlineInputBorder(
//                 borderRadius: BorderRadius.circular(8),
//                 borderSide: BorderSide(color: Colors.grey.shade300)),
//             focusedBorder: OutlineInputBorder(
//                 borderRadius: BorderRadius.circular(8),
//                 borderSide: const BorderSide(color: primary, width: 1.5)),
//             errorBorder: OutlineInputBorder(
//                 borderRadius: BorderRadius.circular(8),
//                 borderSide: const BorderSide(color: Colors.red)),
//             filled: true,
//             fillColor: const Color(0xFFFAFAFA),
//           ),
//         ),
//       ],
//     );
//   }

//   // ── Right Panel ──────────────────────────────────────────────────────────────
//   Widget _buildRightPanel() {
//     return Column(
//       children: [
//         // Riskometer card
//         Container(
//           decoration: BoxDecoration(
//             color: Colors.white,
//             borderRadius: BorderRadius.circular(12),
//             border: Border.all(color: Colors.grey.shade200),
//             boxShadow: [
//               BoxShadow(
//                   color: Colors.grey.withValues(alpha: 0.07),
//                   blurRadius: 10,
//                   offset: const Offset(0, 3))
//             ],
//           ),
//           child: Column(
//             children: [
//               // Card header
//               Container(
//                 padding: const EdgeInsets.symmetric(
//                     horizontal: 20, vertical: 14),
//                 decoration: BoxDecoration(
//                   color: const Color(0xFFF5F7FA),
//                   borderRadius:
//                       const BorderRadius.vertical(top: Radius.circular(12)),
//                   border: Border(
//                       bottom: BorderSide(color: Colors.grey.shade200)),
//                 ),
//                 child: Row(children: [
//                   Container(
//                     padding: const EdgeInsets.all(7),
//                     decoration: BoxDecoration(
//                         color: const Color(0xFFFFE5E5),
//                         borderRadius: BorderRadius.circular(8)),
//                     child: const Icon(Icons.speed_rounded,
//                         color: Color(0xFFD32F2F), size: 16),
//                   ),
//                   const SizedBox(width: 10),
//                   const Text('Riskometer',
//                       style: TextStyle(
//                           fontWeight: FontWeight.w700,
//                           fontSize: 14,
//                           color: Color(0xFF1A1A2E))),
//                   const Spacer(),
//                   if (_analysed)
//                     Container(
//                       padding: const EdgeInsets.symmetric(
//                           horizontal: 10, vertical: 4),
//                       decoration: BoxDecoration(
//                         color: _getRiskLevel(_riskScore)
//                             .bgColor,
//                         borderRadius: BorderRadius.circular(20),
//                       ),
//                       child: Text(
//                         'Score: ${_riskScore.toStringAsFixed(1)} / 100',
//                         style: TextStyle(
//                             fontSize: 11,
//                             fontWeight: FontWeight.w700,
//                             color: _getRiskLevel(_riskScore).color),
//                       ),
//                     ),
//                 ]),
//               ),

//               Padding(
//                 padding: const EdgeInsets.fromLTRB(20, 28, 20, 24),
//                 child: AnimatedBuilder(
//                   animation: _needleAnimation,
//                   builder: (context, _) {
//                     final displayScore = _analysed
//                         ? _needleAnimation.value
//                         : 0.0;
//                     return _buildRiskometer(displayScore);
//                   },
//                 ),
//               ),
//             ],
//           ),
//         ),

//         const SizedBox(height: 16),

//         // Result card
//         AnimatedOpacity(
//           opacity: _analysed ? 1.0 : 0.0,
//           duration: const Duration(milliseconds: 600),
//           child: _analysed
//               ? _buildResultCard(_getRiskLevel(_riskScore))
//               : const SizedBox.shrink(),
//         ),

//         if (_analysed) ...[
//           const SizedBox(height: 16),
//           _buildBreakdownCard(),
//         ],
//       ],
//     );
//   }

//   // ── Riskometer Gauge ─────────────────────────────────────────────────────────
//   Widget _buildRiskometer(double score) {
//     return Column(
//       children: [
//         SizedBox(
//           height: 220,
//           child: CustomPaint(
//             painter: _RiskometerPainter(score: score),
//             child: Center(
//               child: Padding(
//                 padding: const EdgeInsets.only(top: 120),
//                 child: Column(
//                   mainAxisSize: MainAxisSize.min,
//                   children: [
//                     Text(
//                       _analysed
//                           ? score.toStringAsFixed(1)
//                           : '--',
//                       style: TextStyle(
//                         fontSize: 36,
//                         fontWeight: FontWeight.w900,
//                         color: _analysed
//                             ? _getRiskLevel(score).color
//                             : Colors.grey[300],
//                         height: 1,
//                       ),
//                     ),
//                     Text(
//                       _analysed ? 'Risk Index' : 'Enter values to analyse',
//                       style: TextStyle(
//                           fontSize: 11, color: Colors.grey[400]),
//                     ),
//                   ],
//                 ),
//               ),
//             ),
//           ),
//         ),

//         const SizedBox(height: 8),

//         // Zone labels row
//         Row(
//           mainAxisAlignment: MainAxisAlignment.spaceBetween,
//           children: const [
//             _ZoneLabel('LOW',             Color(0xFF2E7D32)),
//             _ZoneLabel('LOW–MOD',         Color(0xFF558B2F)),
//             _ZoneLabel('MODERATE',        Color(0xFFF9A825)),
//             _ZoneLabel('MOD–HIGH',        Color(0xFFEF6C00)),
//             _ZoneLabel('HIGH',            Color(0xFFD32F2F)),
//             _ZoneLabel('VERY HIGH',       Color(0xFF7B0000)),
//           ],
//         ),
//       ],
//     );
//   }

//   // ── Result Card ──────────────────────────────────────────────────────────────
//   Widget _buildResultCard(_RiskLevel level) {
//     return Container(
//       decoration: BoxDecoration(
//         color: level.bgColor,
//         borderRadius: BorderRadius.circular(12),
//         border: Border.all(color: level.color.withValues(alpha: 0.3)),
//       ),
//       padding: const EdgeInsets.all(18),
//       child: Row(
//         children: [
//           Container(
//             padding: const EdgeInsets.all(10),
//             decoration: BoxDecoration(
//                 color: level.color.withValues(alpha: 0.15),
//                 shape: BoxShape.circle),
//             child: Icon(level.icon, color: level.color, size: 24),
//           ),
//           const SizedBox(width: 14),
//           Expanded(
//             child: Column(
//               crossAxisAlignment: CrossAxisAlignment.start,
//               children: [
//                 Row(children: [
//                   Text(
//                     level.label,
//                     style: TextStyle(
//                         fontSize: 16,
//                         fontWeight: FontWeight.w800,
//                         color: level.color),
//                   ),
//                   const SizedBox(width: 8),
//                   Text('Risk',
//                       style: TextStyle(
//                           fontSize: 14,
//                           fontWeight: FontWeight.w500,
//                           color: level.color.withValues(alpha: 0.7))),
//                 ]),
//                 const SizedBox(height: 4),
//                 Text(level.description,
//                     style: TextStyle(
//                         fontSize: 12,
//                         color: level.color.withValues(alpha: 0.85),
//                         height: 1.5)),
//               ],
//             ),
//           ),
//         ],
//       ),
//     );
//   }

//   // ── Breakdown Card ───────────────────────────────────────────────────────────
//   Widget _buildBreakdownCard() {
//     final T     = double.tryParse(_tempController.text)  ?? 25.0;
//     final RH    = double.tryParse(_rhController.text)    ?? 50.0;
//     final O2    = double.tryParse(_o2Controller.text)    ?? 20.9;
//     final CO    = double.tryParse(_coController.text)    ?? 0.0;
//     final fines = double.tryParse(_finesController.text) ?? 10.0;
//     final gw    = _gradeToRiskWeight(_selectedGrade);

//     final items = [
//       _BreakdownItem('Coal Grade ($_selectedGrade)', gw,          const Color(0xFFEF6C00), 35),
//       _BreakdownItem('Temperature (${T.toStringAsFixed(0)}°C)',   ((T - 10) / 50.0).clamp(0, 1),   const Color(0xFFE53935), 20),
//       _BreakdownItem('Humidity (${RH.toStringAsFixed(0)}%)',      ((100 - RH) / 100.0).clamp(0, 1), const Color(0xFF1E88E5), 15),
//       _BreakdownItem('CO (${CO.toStringAsFixed(0)} ppb)',         (CO / 500.0).clamp(0, 1),          const Color(0xFF6D4C41), 15),
//       _BreakdownItem('O₂ (${O2.toStringAsFixed(1)}%)',            ((21 - O2) / 21.0).clamp(0, 1),   const Color(0xFF43A047), 10),
//       _BreakdownItem('Fines (${fines.toStringAsFixed(0)}%)',      (fines / 100.0).clamp(0, 1),       const Color(0xFF8D6E63), 5),
//     ];

//     return Container(
//       decoration: BoxDecoration(
//         color: Colors.white,
//         borderRadius: BorderRadius.circular(12),
//         border: Border.all(color: Colors.grey.shade200),
//         boxShadow: [
//           BoxShadow(
//               color: Colors.grey.withValues(alpha: 0.07),
//               blurRadius: 10,
//               offset: const Offset(0, 3))
//         ],
//       ),
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           Container(
//             padding:
//                 const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
//             decoration: BoxDecoration(
//               color: const Color(0xFFF5F7FA),
//               borderRadius:
//                   const BorderRadius.vertical(top: Radius.circular(12)),
//               border:
//                   Border(bottom: BorderSide(color: Colors.grey.shade200)),
//             ),
//             child: Row(children: [
//               Container(
//                 padding: const EdgeInsets.all(7),
//                 decoration: BoxDecoration(
//                     color: const Color(0xFFE8F0FB),
//                     borderRadius: BorderRadius.circular(8)),
//                 child: const Icon(Icons.bar_chart_rounded,
//                     color: primary, size: 16),
//               ),
//               const SizedBox(width: 10),
//               const Text('Risk Factor Breakdown',
//                   style: TextStyle(
//                       fontWeight: FontWeight.w700,
//                       fontSize: 14,
//                       color: Color(0xFF1A1A2E))),
//             ]),
//           ),
//           Padding(
//             padding: const EdgeInsets.all(20),
//             child: Column(
//               children: items
//                   .map((item) => _buildBreakdownRow(item))
//                   .toList(),
//             ),
//           ),
//         ],
//       ),
//     );
//   }

//   Widget _buildBreakdownRow(_BreakdownItem item) {
//     final contribution = (item.normalizedValue * item.weight).toStringAsFixed(1);
//     return Padding(
//       padding: const EdgeInsets.only(bottom: 12),
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           Row(
//             children: [
//               Container(
//                   width: 8,
//                   height: 8,
//                   decoration: BoxDecoration(
//                       color: item.color, shape: BoxShape.circle)),
//               const SizedBox(width: 8),
//               Expanded(
//                   child: Text(item.label,
//                       style: const TextStyle(
//                           fontSize: 12, fontWeight: FontWeight.w500))),
//               Text('$contribution / ${item.weight}',
//                   style: TextStyle(
//                       fontSize: 11,
//                       color: Colors.grey[500],
//                       fontWeight: FontWeight.w500)),
//             ],
//           ),
//           const SizedBox(height: 6),
//           ClipRRect(
//             borderRadius: BorderRadius.circular(4),
//             child: LinearProgressIndicator(
//               value: item.normalizedValue,
//               minHeight: 6,
//               backgroundColor: Colors.grey.shade100,
//               valueColor: AlwaysStoppedAnimation<Color>(item.color),
//             ),
//           ),
//         ],
//       ),
//     );
//   }
// }

// // ── Custom Painter: Riskometer ────────────────────────────────────────────────
// class _RiskometerPainter extends CustomPainter {
//   final double score; // 0–100

//   const _RiskometerPainter({required this.score});

//   @override
//   void paint(Canvas canvas, Size size) {
//     final cx = size.width / 2;
//     final cy = size.height * 0.88;
//     final outerR = size.width * 0.46;
//     final innerR = outerR * 0.68;
//     final needleR = outerR * 0.82;

//     // Zone colors (6 zones)
//     final zones = [
//       const Color(0xFF2E7D32),
//       const Color(0xFF558B2F),
//       const Color(0xFFF9A825),
//       const Color(0xFFEF6C00),
//       const Color(0xFFD32F2F),
//       const Color(0xFF7B0000),
//     ];

//     // Draw arc zones — 180° spread (π radians), from left (π) to right (0)
//     const startAngle = pi;       // left
//     const totalSweep = pi;       // 180°
//     const zoneCount  = 6;
//     const zoneSweep  = totalSweep / zoneCount;
//     const gapRad     = 0.018;    // small gap between zones

//     final trackPaint = Paint()
//       ..style = PaintingStyle.stroke
//       ..strokeWidth = outerR - innerR
//       ..strokeCap = StrokeCap.butt;

//     for (int i = 0; i < zoneCount; i++) {
//       trackPaint.color = zones[i];
//       canvas.drawArc(
//         Rect.fromCircle(
//             center: Offset(cx, cy), radius: (outerR + innerR) / 2),
//         startAngle + i * zoneSweep + gapRad,
//         zoneSweep - gapRad * 2,
//         false,
//         trackPaint,
//       );
//     }

//     // Outer ring shadow/border
//     final borderPaint = Paint()
//       ..style = PaintingStyle.stroke
//       ..strokeWidth = 1.5
//       ..color = Colors.grey.shade200;
//     canvas.drawArc(
//       Rect.fromCircle(center: Offset(cx, cy), radius: outerR),
//       pi, pi, false, borderPaint,
//     );

//     // ── Needle ───────────────────────────────────────────────────────────────
//     // score 0 → left (π), score 100 → right (0)
//     final needleAngle = pi - (score / 100.0) * pi;

//     final needleTip = Offset(
//       cx + needleR * cos(needleAngle),
//       cy + needleR * sin(needleAngle),
//     );
//     final needleBase1 = Offset(
//       cx + 10 * cos(needleAngle + pi / 2),
//       cy + 10 * sin(needleAngle + pi / 2),
//     );
//     final needleBase2 = Offset(
//       cx + 10 * cos(needleAngle - pi / 2),
//       cy + 10 * sin(needleAngle - pi / 2),
//     );

//     final needlePath = Path()
//       ..moveTo(needleTip.dx, needleTip.dy)
//       ..lineTo(needleBase1.dx, needleBase1.dy)
//       ..lineTo(needleBase2.dx, needleBase2.dy)
//       ..close();

//     // Needle shadow
//     canvas.drawPath(
//       needlePath,
//       Paint()
//         ..color = Colors.black.withValues(alpha: 0.15)
//         ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
//     );

//     canvas.drawPath(
//         needlePath,
//         Paint()
//           ..color = const Color(0xFF1A1A2E)
//           ..style = PaintingStyle.fill);

//     // Pivot circle
//     canvas.drawCircle(
//       Offset(cx, cy),
//       14,
//       Paint()
//         ..color = const Color(0xFF1A1A2E)
//         ..style = PaintingStyle.fill,
//     );
//     canvas.drawCircle(
//       Offset(cx, cy),
//       7,
//       Paint()
//         ..color = Colors.white
//         ..style = PaintingStyle.fill,
//     );

//     // Tick marks
//     final tickPaint = Paint()
//       ..color = Colors.grey.shade400
//       ..strokeWidth = 1.2
//       ..style = PaintingStyle.stroke;

//     for (int t = 0; t <= 10; t++) {
//       final tickAngle = pi + (t / 10.0) * pi;
//       final isMajor   = t % 2 == 0;
//       final r1 = outerR + 6;
//       final r2 = outerR + (isMajor ? 14 : 9);
//       canvas.drawLine(
//         Offset(cx + r1 * cos(tickAngle), cy + r1 * sin(tickAngle)),
//         Offset(cx + r2 * cos(tickAngle), cy + r2 * sin(tickAngle)),
//         tickPaint,
//       );
//     }
//   }

//   @override
//   bool shouldRepaint(_RiskometerPainter old) => old.score != score;
// }

// // ── Zone Label Widget ─────────────────────────────────────────────────────────
// class _ZoneLabel extends StatelessWidget {
//   final String text;
//   final Color  color;
//   const _ZoneLabel(this.text, this.color);

//   @override
//   Widget build(BuildContext context) {
//     return Column(
//       children: [
//         Container(width: 8, height: 8,
//             decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
//         const SizedBox(height: 3),
//         Text(text,
//             style: TextStyle(
//                 fontSize: 8,
//                 fontWeight: FontWeight.w700,
//                 color: color,
//                 letterSpacing: 0.3)),
//       ],
//     );
//   }
// }

// // ── Data Classes ──────────────────────────────────────────────────────────────
// class _RiskLevel {
//   final String  label;
//   final Color   color;
//   final Color   bgColor;
//   final IconData icon;
//   final String  description;
//   const _RiskLevel(
//       this.label, this.color, this.bgColor, this.icon, this.description);
// }

// class _BreakdownItem {
//   final String label;
//   final double normalizedValue; // 0–1
//   final Color  color;
//   final double weight;          // max contribution points
//   const _BreakdownItem(
//       this.label, this.normalizedValue, this.color, this.weight);
// }




import 'dart:math';
import 'package:flutter/material.dart';
import 'package:mine_wadhwani/core/di/injection_container.dart';
import 'package:mine_wadhwani/core/error/exceptions.dart';
import 'package:mine_wadhwani/core/network/api_client.dart';

class RiskAnalysisScreen extends StatefulWidget {
  const RiskAnalysisScreen({super.key});

  @override
  State<RiskAnalysisScreen> createState() => _RiskAnalysisScreenState();
}

/// Stockpile risk analysis using the trained heating-grade model + safety rules + AI explanation
/// (backend POST /api/v1/risk-monitor/assess, the same pipeline as the Risk Monitor agent).
class _RiskAnalysisScreenState extends State<RiskAnalysisScreen>
    with TickerProviderStateMixin {
  static const Color primary = Color(0xFF1F579C);
  static const Color bg      = Color(0xFFF5F7FA);

  final _formKey = GlobalKey<FormState>();

  String _selectedGrade = 'G7';
  final List<String> _grades = [
    'G1','G2','G3','G4','G5','G6',
    'G7','G8','G9','G10','G11','G12','G13','G14',
  ];

  final _tempController = TextEditingController(text: '38');
  final _o2Controller   = TextEditingController(text: '20.9');
  final _coController   = TextEditingController(text: '20');
  final _co2Controller  = TextEditingController();
  final _c2h4Controller = TextEditingController();

  Map<String, dynamic>? _result;
  bool   _loading       = false;
  double _previousNeedle = 0;
  double _previousIndex  = 0;

  late AnimationController _needleController;
  late Animation<double>   _needleAnimation;
  late Animation<double>   _indexAnimation;

  bool get _analysed => _result != null;
  int get _grade => (_result?['grade'] as num?)?.toInt() ?? 0;
  double get _riskIndex => (_result?['risk_index'] as num?)?.toDouble() ?? 0;
  Map<String, dynamic> get _explanation => ((_result?['explanation'] as Map?) ?? {}).cast<String, dynamic>();

  @override
  void initState() {
    super.initState();
    _needleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );
    _needleAnimation = Tween<double>(begin: 0, end: 0).animate(_needleController);
    _indexAnimation  = Tween<double>(begin: 0, end: 0).animate(_needleController);
  }

  @override
  void dispose() {
    _needleController.dispose();
    _tempController.dispose();
    _o2Controller.dispose();
    _coController.dispose();
    _co2Controller.dispose();
    _c2h4Controller.dispose();
    super.dispose();
  }

  String _gradeGroup(String grade) {
    final n = int.tryParse(grade.replaceAll('G', '')) ?? 7;
    if (n <= 3)  return 'High-rank Bituminous · Low Tendency';
    if (n <= 6)  return 'Good Quality Bituminous · Low–Moderate';
    if (n <= 9)  return 'Medium Rank · Moderate Tendency';
    if (n <= 12) return 'Low Rank · High Tendency';
    return 'Very Low Rank / High Moisture · Very High Tendency';
  }

  String _gradeHint(String g) {
    final n = int.tryParse(g.replaceAll('G', '')) ?? 7;
    if (n <= 3)  return '>6200 kcal/kg';
    if (n <= 6)  return '5600–6200 kcal/kg';
    if (n <= 9)  return '4900–5600 kcal/kg';
    if (n <= 12) return '3400–4900 kcal/kg';
    return '<3400 kcal/kg';
  }

  Future<void> _analyse() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    String? v(TextEditingController c) => c.text.trim().isEmpty ? null : c.text.trim();
    try {
      final res = await sl<ApiClient>().post('/api/v1/risk-monitor/assess', data: {
        'environment': 'surface_stockpile',
        'coal_grade': _selectedGrade,
        'coal_temp_c': v(_tempController),
        'o2_pct': v(_o2Controller),
        'co_ppm': v(_coController),
        'co2_ppm': v(_co2Controller),
        'c2h4_ppm': v(_c2h4Controller),
      });
      final data = ((res.data as Map)['data'] as Map).cast<String, dynamic>();
      if (!mounted) return;
      final grade = (data['grade'] as num).toInt();
      final index = (data['risk_index'] as num).toDouble();
      // Gauge has one zone per grade (0-5); keep the needle inside the final grade's zone.
      const zone = 100 / 6;
      final needle = index.clamp(grade * zone + 1, (grade + 1) * zone - 1).toDouble();
      final curve = CurvedAnimation(parent: _needleController, curve: Curves.easeInOutCubic);
      _needleAnimation = Tween<double>(begin: _previousNeedle, end: needle).animate(curve);
      _indexAnimation  = Tween<double>(begin: _previousIndex, end: index).animate(curve);
      _needleController.forward(from: 0);
      _previousNeedle = needle;
      _previousIndex  = index;
      setState(() {
        _result  = data;
        _loading = false;
      });
    } on ServerException catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  static const _zoneColors = [
    Color(0xFF2E7D32), Color(0xFF558B2F), Color(0xFFF9A825),
    Color(0xFFEF6C00), Color(0xFFD32F2F), Color(0xFF7B0000),
  ];
  static const _zoneBg = [
    Color(0xFFE8F5E9), Color(0xFFF1F8E9), Color(0xFFFFFDE7),
    Color(0xFFFFF3E0), Color(0xFFFFEBEE), Color(0xFFFFCDD2),
  ];
  static const _levels = ['Safe', 'Low', 'Moderate', 'High', 'Severe', 'Critical'];
  static const _icons = [
    Icons.check_circle_rounded, Icons.info_rounded, Icons.warning_amber_rounded,
    Icons.warning_rounded, Icons.dangerous_rounded, Icons.local_fire_department_rounded,
  ];

  _RiskLevel _getRiskLevel(int grade) {
    final g = grade.clamp(0, 5);
    final summary = _explanation['summary'] as String? ?? '';
    return _RiskLevel(tr(_levels[g]), _zoneColors[g], _zoneBg[g], _icons[g], summary);
  }

  int _zoneOf(double needle) => (needle / (100 / 6)).floor().clamp(0, 5);

  // ── BUILD ────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bg,
      body: Column(
        children: [
          _buildTopBar(context),

          // ── Page header ───────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
            child: Row(children: [
              Container(
                width: 4, height: 38,
                decoration: BoxDecoration(
                    color: primary, borderRadius: BorderRadius.circular(4)),
              ),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(tr('Stockpile Risk Analysis'),
                    style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: primary,
                        height: 1.1)),
                Text(tr('risk_analysis_sub'),
                    style: TextStyle(fontSize: 10, color: Colors.grey[500])),
              ])),
              // Method chip only where there is room (tablets / landscape).
              if (MediaQuery.sizeOf(context).width >= 760)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFFE8F0FB),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: primary.withValues(alpha: 0.2)),
                ),
                child: Row(children: [
                  Icon(Icons.auto_awesome, color: primary, size: 13),
                  SizedBox(width: 5),
                  Text(tr('ai_method'),
                      style: TextStyle(
                          fontSize: 10,
                          color: primary,
                          fontWeight: FontWeight.w600)),
                ]),
              ),
            ]),
          ),

          // ── Main content — side by side on tablets, scrolls on phones ─────
          Expanded(
            child: LayoutBuilder(builder: (context, box) {
              if (box.maxWidth >= 760) {
                return Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 14),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SizedBox(width: 300, child: _buildInputForm()),
                      const SizedBox(width: 18),
                      Expanded(child: _buildRightPanel()),
                    ],
                  ),
                );
              }
              // Panels use flex children internally, so give them fixed heights here.
              return ListView(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                children: [
                  SizedBox(height: 620, child: _buildInputForm()),
                  const SizedBox(height: 16),
                  SizedBox(height: 760, child: _buildRightPanel()),
                ],
              );
            }),
          ),
        ],
      ),
    );
  }

  // ── Top Bar ──────────────────────────────────────────────────────────────────
  Widget _buildTopBar(BuildContext context) {
    return Container(
      color: primary,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: SafeArea(
        bottom: false,
        child: Row(children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded,
                color: Colors.white, size: 18),
            onPressed: () => Navigator.of(context).pop(),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
          const SizedBox(width: 14),
          Container(width: 1, height: 28, color: Colors.white24),
          const SizedBox(width: 14),
          Flexible(
            child: Text(tr('Risk Analysis'),
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w700)),
          ),
          const Spacer(),
          // Continuous AI monitoring (ML + rules + forecast + LLM) lives in the Risk Monitor agent.
          if (MediaQuery.sizeOf(context).width < 700)
            IconButton(
              tooltip: tr('open_monitor'),
              onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const RiskMonitorScreen())),
              icon: const Icon(Icons.sensors, color: Colors.white, size: 20),
            )
          else
            TextButton.icon(
              onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const RiskMonitorScreen())),
              icon: const Icon(Icons.sensors, color: Colors.white, size: 16),
              label: Text(tr('open_monitor'), style: const TextStyle(color: Colors.white, fontSize: 12)),
            ),
          Flexible(child: FittedBox(fit: BoxFit.scaleDown, child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white12,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white24, width: 0.8),
            ),
            child: Row(children: [
              Icon(Icons.auto_awesome, color: Colors.white70, size: 13),
              SizedBox(width: 6),
              Text(tr('ai_powered'),
                  style: TextStyle(color: Colors.white70, fontSize: 11)),
            ]),
          ))),
        ]),
      ),
    );
  }

  // ── Input Form ───────────────────────────────────────────────────────────────
  String? Function(String?) _range(double lo, double hi, {bool optional = false}) => (v) {
        if (optional && (v ?? '').trim().isEmpty) return null;
        final val = double.tryParse(v ?? '');
        if (val == null) return 'Invalid';
        if (val < lo || val > hi) return '${lo.toStringAsFixed(0)}–${hi.toStringAsFixed(0)}';
        return null;
      };

  Widget _buildInputForm() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [BoxShadow(
            color: Colors.grey.withValues(alpha: 0.07),
            blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Form(
        key: _formKey,
        child: Column(children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
            decoration: BoxDecoration(
              color: const Color(0xFFF5F7FA),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
              border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
            ),
            child: Row(children: [
              Container(
                padding: const EdgeInsets.all(5),
                decoration: BoxDecoration(
                    color: const Color(0xFFE8F0FB),
                    borderRadius: BorderRadius.circular(6)),
                child: const Icon(Icons.sensors_rounded, color: primary, size: 13),
              ),
              const SizedBox(width: 8),
              Text(tr('Sensor Parameters'),
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12,
                      color: Color(0xFF1A1A2E))),
            ]),
          ),

          // Fields
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
              child: Column(children: [
                _buildGradeDropdown(),
                const SizedBox(height: 7),
                _buildInputField(controller: _tempController, label: tr('coal_temp'),            unit: '°C',  hint: '25–60',   icon: Icons.thermostat_rounded, iconColor: const Color(0xFFE53935), validator: _range(-10, 600)),
                const SizedBox(height: 7),
                _buildInputField(controller: _o2Controller,   label: tr('Oxygen (O₂)'),          unit: '%',   hint: '0–21',    icon: Icons.air_rounded,        iconColor: const Color(0xFF43A047), validator: _range(0, 21)),
                const SizedBox(height: 7),
                _buildInputField(controller: _coController,   label: tr('Carbon Monoxide (CO)'), unit: 'ppm', hint: '0–500',   icon: Icons.cloud_rounded,      iconColor: const Color(0xFF6D4C41), validator: _range(0, 100000)),
                const SizedBox(height: 7),
                _buildInputField(controller: _co2Controller,  label: tr('co2_optional'),         unit: 'ppm', hint: '400–5000', icon: Icons.cloud_queue_rounded, iconColor: const Color(0xFF1E88E5), validator: _range(0, 1000000, optional: true)),
                const SizedBox(height: 7),
                _buildInputField(controller: _c2h4Controller, label: tr('c2h4_optional'),        unit: 'ppm', hint: '0–10',    icon: Icons.local_fire_department_outlined, iconColor: const Color(0xFF8D6E63), validator: _range(0, 100000, optional: true)),
                const Spacer(),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _loading ? null : _analyse,
                    icon: _loading
                        ? const SizedBox(width: 14, height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.analytics_rounded, size: 16),
                    label: Text(_loading ? tr('Analysing...') : tr('Analyse Risk'),
                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
                      elevation: 0,
                    ),
                  ),
                ),
              ]),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _buildGradeDropdown() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Container(padding: const EdgeInsets.all(5),
          decoration: BoxDecoration(color: const Color(0xFFFFF3E0), borderRadius: BorderRadius.circular(5)),
          child: const Icon(Icons.layers_rounded, color: Color(0xFFEF6C00), size: 12)),
        const SizedBox(width: 7),
        Text(tr('Coal Grade'), style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF1A1A2E))),
      ]),
      const SizedBox(height: 4),
      DropdownButtonFormField<String>(
        value: _selectedGrade,
        isExpanded: true,
        isDense: true,
        decoration: InputDecoration(
          contentPadding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(7), borderSide: BorderSide(color: Colors.grey.shade300)),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(7), borderSide: BorderSide(color: Colors.grey.shade300)),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(7), borderSide: const BorderSide(color: primary, width: 1.5)),
          filled: true, fillColor: const Color(0xFFFAFAFA), isDense: true,
        ),
        style: const TextStyle(fontSize: 12, color: Color(0xFF1A1A2E)),
        items: _grades.map((g) => DropdownMenuItem(value: g,
            child: Text('$g  ·  ${_gradeHint(g)}'))).toList(),
        onChanged: (v) => setState(() => _selectedGrade = v!),
      ),
      const SizedBox(height: 2),
      Text(_gradeGroup(_selectedGrade),
          style: TextStyle(fontSize: 9, color: Colors.grey[500])),
    ]);
  }

  Widget _buildInputField({
    required TextEditingController controller,
    required String label, required String unit,
    required String hint, required IconData icon,
    required Color iconColor,
    String? Function(String?)? validator,
  }) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Container(padding: const EdgeInsets.all(5),
          decoration: BoxDecoration(color: iconColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(5)),
          child: Icon(icon, color: iconColor, size: 12)),
        const SizedBox(width: 7),
        Flexible(child: Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF1A1A2E)))),
      ]),
      const SizedBox(height: 4),
      TextFormField(
        controller: controller,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        validator: validator,
        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
        decoration: InputDecoration(
          hintText: hint,
          suffixText: unit,
          suffixStyle: TextStyle(color: Colors.grey[500], fontSize: 11),
          contentPadding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
          isDense: true,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(7), borderSide: BorderSide(color: Colors.grey.shade300)),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(7), borderSide: BorderSide(color: Colors.grey.shade300)),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(7), borderSide: const BorderSide(color: primary, width: 1.5)),
          errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(7), borderSide: const BorderSide(color: Colors.red)),
          filled: true, fillColor: const Color(0xFFFAFAFA),
        ),
      ),
    ]);
  }

  // ── Right Panel ───────────────────────────────────────────────────────────────
  Widget _buildRightPanel() {
    final level = _getRiskLevel(_grade);
    return Column(children: [
      // Riskometer card
      Expanded(
        flex: 52,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade200),
            boxShadow: [BoxShadow(color: Colors.grey.withValues(alpha: 0.07), blurRadius: 8, offset: const Offset(0, 2))],
          ),
          child: Column(children: [
            // Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
              decoration: BoxDecoration(
                color: const Color(0xFFF5F7FA),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
              ),
              child: Row(children: [
                Container(padding: const EdgeInsets.all(5),
                  decoration: BoxDecoration(color: const Color(0xFFFFE5E5), borderRadius: BorderRadius.circular(6)),
                  child: const Icon(Icons.speed_rounded, color: Color(0xFFD32F2F), size: 13)),
                const SizedBox(width: 8),
                Text(tr('Riskometer'), style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: Color(0xFF1A1A2E))),
                const Spacer(),
                if (_analysed)
                  Flexible(child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                    decoration: BoxDecoration(color: level.bgColor, borderRadius: BorderRadius.circular(20)),
                    child: Text('${tr('grade')} $_grade · ${tr('risk_index')} ${_riskIndex.round()} / 100',
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: level.color)),
                  )),
              ]),
            ),

            // Gauge
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 6, 12, 8),
                child: AnimatedBuilder(
                  animation: _needleAnimation,
                  builder: (context, _) {
                    final ds = _analysed ? _needleAnimation.value : 0.0;
                    return Column(children: [
                      Expanded(
                        child: LayoutBuilder(builder: (ctx, c) => CustomPaint(
                          size: Size(c.maxWidth, c.maxHeight),
                          painter: _RiskometerPainter(
                            score: ds,
                            levelColor: _analysed ? _zoneColors[_zoneOf(ds)] : Colors.grey.shade300,
                            scoreText: _analysed ? _indexAnimation.value.round().toString() : '--',
                          ),
                        )),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          for (var i = 0; i < 6; i++) _ZoneLabel(tr(_levels[i]).toUpperCase(), _zoneColors[i]),
                        ],
                      ),
                    ]);
                  },
                ),
              ),
            ),
          ]),
        ),
      ),

      const SizedBox(height: 10),

      // Result card
      AnimatedSwitcher(
        duration: const Duration(milliseconds: 400),
        child: _analysed ? _buildResultCard(level) : _buildPlaceholderCard(),
      ),

      const SizedBox(height: 10),

      // Model factor contributions
      Expanded(flex: 28, child: _buildBreakdownCard()),
    ]);
  }

  Widget _buildResultCard(_RiskLevel level) {
    final alerts = (_explanation['active_safety_alerts'] as List?)?.length ?? 0;
    return Container(
      key: ValueKey(_result.hashCode),
      decoration: BoxDecoration(
        color: level.bgColor,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: level.color.withValues(alpha: 0.3)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(children: [
        Container(padding: const EdgeInsets.all(7),
          decoration: BoxDecoration(color: level.color.withValues(alpha: 0.15), shape: BoxShape.circle),
          child: Icon(level.icon, color: level.color, size: 18)),
        const SizedBox(width: 11),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Wrap(spacing: 6, crossAxisAlignment: WrapCrossAlignment.center, children: [
            Text(level.label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: level.color)),
            Text(tr('Risk'), style: TextStyle(fontSize: 12, color: level.color.withValues(alpha: 0.7))),
            if (alerts > 0)
              Text('· $alerts ${tr('safety_alerts')}', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: level.color)),
          ]),
          const SizedBox(height: 2),
          Text(level.description,
              maxLines: 3, overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 10, color: level.color.withValues(alpha: 0.85), height: 1.4)),
        ])),
        TextButton(
          onPressed: () => Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => RiskAssessmentScreen(monitor: {'zone': tr('Risk Analysis')}, assessment: _result!))),
          child: Text(tr('details')),
        ),
      ]),
    );
  }

  Widget _buildPlaceholderCard() {
    return Container(
      key: const ValueKey('placeholder'),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.grey.shade200)),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      child: Row(children: [
        Icon(Icons.info_outline_rounded, color: Colors.grey[300], size: 20),
        const SizedBox(width: 10),
        Expanded(child: Text(tr('Enter values and tap Analyse Risk to see results'),
            style: TextStyle(fontSize: 11, color: Colors.grey[400]))),
      ]),
    );
  }

  static const _featureLabels = {
    'coal_temp_c': 'coal_temp',
    'log_co': 'CO',
    'co_co2': 'CO/CO₂',
    'graham': "Graham's ratio",
    'o2_deficit': 'O₂ deficit',
    'c2h4_present': 'C₂H₄',
  };

  Widget _buildBreakdownCard() {
    final ml = ((_result?['ml'] as Map?) ?? {}).cast<String, dynamic>();
    final contrib = ((ml['contributions'] as Map?) ?? {}).cast<String, dynamic>();
    final maxAbs = contrib.values.fold<double>(0.01, (m, v) => max(m, (v as num).abs().toDouble()));

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [BoxShadow(color: Colors.grey.withValues(alpha: 0.07), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Column(children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          decoration: BoxDecoration(
            color: const Color(0xFFF5F7FA),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
            border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
          ),
          child: Row(children: [
            Container(padding: const EdgeInsets.all(5),
              decoration: BoxDecoration(color: const Color(0xFFE8F0FB), borderRadius: BorderRadius.circular(6)),
              child: const Icon(Icons.bar_chart_rounded, color: primary, size: 13)),
            const SizedBox(width: 8),
            Expanded(child: Text(tr('factor_contributions'),
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: Color(0xFF1A1A2E)))),
            if (ml['confidence'] != null)
              Text('${tr('confidence')} ${((ml['confidence'] as num) * 100).round()}%',
                  style: TextStyle(fontSize: 10, color: Colors.grey[600], fontWeight: FontWeight.w600)),
          ]),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 6, 12, 8),
            child: contrib.isEmpty
                ? Center(child: Text(tr('Enter values and tap Analyse Risk to see results'),
                    style: TextStyle(fontSize: 11, color: Colors.grey[400])))
                : Column(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      for (final e in contrib.entries)
                        Row(children: [
                          Container(width: 7, height: 7,
                              decoration: BoxDecoration(
                                  color: (e.value as num) >= 0 ? const Color(0xFFD32F2F) : const Color(0xFF2E7D32),
                                  shape: BoxShape.circle)),
                          const SizedBox(width: 7),
                          SizedBox(width: 120,
                            child: Text(tr(_featureLabels[e.key] ?? e.key),
                                style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w500),
                                overflow: TextOverflow.ellipsis)),
                          Expanded(child: ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: ((e.value as num).abs() / maxAbs).clamp(0.02, 1.0).toDouble(), minHeight: 6,
                              backgroundColor: Colors.grey.shade100,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                  (e.value as num) >= 0 ? const Color(0xFFD32F2F) : const Color(0xFF2E7D32)),
                            ),
                          )),
                          const SizedBox(width: 7),
                          SizedBox(width: 40,
                            child: Text('${(e.value as num) >= 0 ? '+' : ''}${(e.value as num).toStringAsFixed(2)}',
                                textAlign: TextAlign.right,
                                style: TextStyle(fontSize: 9, color: Colors.grey[600], fontWeight: FontWeight.w600))),
                        ]),
                      Text(tr('vs_average'), style: TextStyle(fontSize: 9, color: Colors.grey[500])),
                    ],
                  ),
          ),
        ),
      ]),
    );
  }
}

// ── Custom Painter ────────────────────────────────────────────────────────────
class _RiskometerPainter extends CustomPainter {
  final double score;
  final Color  levelColor;
  final String scoreText;

  const _RiskometerPainter({
    required this.score,
    required this.levelColor,
    required this.scoreText,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Place pivot at bottom-centre, gauge radius = half the width (capped by height)
    final cx = size.width / 2;
    final cy = size.height;                             // pivot at very bottom edge
    final outerR = min(size.width / 2.1, size.height * 0.90);
    final innerR = outerR * 0.66;
    final trackR = (outerR + innerR) / 2;
    final trackW = outerR - innerR;

    final zones = [
      const Color(0xFF2E7D32),
      const Color(0xFF558B2F),
      const Color(0xFFF9A825),
      const Color(0xFFEF6C00),
      const Color(0xFFD32F2F),
      const Color(0xFF7B0000),
    ];

    const gapRad    = 0.018;
    const zoneCount = 6;
    const zoneSweep = pi / zoneCount;

    final trackPaint = Paint()
      ..style      = PaintingStyle.stroke
      ..strokeWidth = trackW
      ..strokeCap  = StrokeCap.butt;

    for (int i = 0; i < zoneCount; i++) {
      trackPaint.color = zones[i];
      canvas.drawArc(
        Rect.fromCircle(center: Offset(cx, cy), radius: trackR),
        pi + i * zoneSweep + gapRad,
        zoneSweep - gapRad * 2,
        false,
        trackPaint,
      );
    }

    // Tick marks
    final tickPaint = Paint()
      ..color      = Colors.grey.shade400
      ..strokeWidth = 1.0
      ..style      = PaintingStyle.stroke;

    for (int t = 0; t <= 10; t++) {
      final angle   = pi + (t / 10.0) * pi;
      final isMajor = t % 2 == 0;
      final r1 = outerR + 3;
      final r2 = outerR + (isMajor ? 11 : 6);
      canvas.drawLine(
        Offset(cx + r1 * cos(angle), cy + r1 * sin(angle)),
        Offset(cx + r2 * cos(angle), cy + r2 * sin(angle)),
        tickPaint,
      );
    }

    // ── Needle ──────────────────────────────────────────────────────────────
    // score=0  → left  (angle = π,   i.e. 9-o'clock pointing left)
    // score=50 → up    (angle = π/2, i.e. 12-o'clock pointing straight UP)
    // score=100→ right (angle = 0,   i.e. 3-o'clock pointing right)
    // Because pivot is at cy = size.height (bottom edge), sin is negative
    // in Flutter's coordinate system, so the needle tip travels UPWARD ✓
    // final needleAngle = pi - (score / 100.0) * pi;
    final needleAngle = pi * (1 - (score / 100));
    final needleLen  = outerR * 0.78;
    const baseHalf   = 8.0;

    final tip = Offset(
      cx + needleLen * cos(needleAngle),
      cy - needleLen * sin(needleAngle),   // negative y → upward in Flutter ✓
    );
    final perp = needleAngle + pi / 2;
    final base1 = Offset(cx + baseHalf * cos(perp), cy + baseHalf * sin(perp));
    final base2 = Offset(cx - baseHalf * cos(perp), cy - baseHalf * sin(perp));

    final needlePath = Path()
      ..moveTo(tip.dx,   tip.dy)
      ..lineTo(base1.dx, base1.dy)
      ..lineTo(base2.dx, base2.dy)
      ..close();

    // Shadow
    canvas.drawPath(needlePath,
      Paint()
        ..color      = Colors.black.withValues(alpha: 0.18)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3));
    // Fill
    canvas.drawPath(needlePath,
      Paint()..color = const Color(0xFF1A1A2E)..style = PaintingStyle.fill);

    // Pivot
    canvas.drawCircle(Offset(cx, cy), 12, Paint()..color = const Color(0xFF1A1A2E));
    canvas.drawCircle(Offset(cx, cy), 5,  Paint()..color = Colors.white);

    // ── Score text ──────────────────────────────────────────────────────────
    final scorePainter = TextPainter(
      text: TextSpan(text: scoreText,
          style: TextStyle(fontSize: outerR * 0.26, fontWeight: FontWeight.w900,
              color: levelColor, height: 1)),
      textDirection: TextDirection.ltr,
    )..layout();
    scorePainter.paint(canvas,
        Offset(cx - scorePainter.width / 2, cy - outerR * 0.55 - scorePainter.height / 2));

    final labelPainter = TextPainter(
      text: TextSpan(text: 'Risk Index',
          style: TextStyle(fontSize: outerR * 0.10, color: Colors.grey.shade400, height: 1)),
      textDirection: TextDirection.ltr,
    )..layout();
    labelPainter.paint(canvas,
        Offset(cx - labelPainter.width / 2, cy - outerR * 0.38));
  }

  @override
  bool shouldRepaint(_RiskometerPainter old) =>
      old.score != score || old.levelColor != levelColor;
}

// ── Zone Label ────────────────────────────────────────────────────────────────
class _ZoneLabel extends StatelessWidget {
  final String text;
  final Color  color;
  const _ZoneLabel(this.text, this.color);

  @override
  Widget build(BuildContext context) => Column(children: [
    Container(width: 7, height: 7,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
    const SizedBox(height: 2),
    Text(text, style: TextStyle(fontSize: 8, fontWeight: FontWeight.w700,
        color: color, letterSpacing: 0.2)),
  ]);
}

// ── Data Classes ──────────────────────────────────────────────────────────────
class _RiskLevel {
  final String   label;
  final Color    color;
  final Color    bgColor;
  final IconData icon;
  final String   description;
  const _RiskLevel(this.label, this.color, this.bgColor, this.icon, this.description);
}

