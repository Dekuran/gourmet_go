import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:image_picker/image_picker.dart';
import 'package:flutter_3d_controller/flutter_3d_controller.dart';
import 'package:video_player/video_player.dart';
import 'package:audioplayers/audioplayers.dart';
import '../models/recipe.dart';
import '../models/line_cook.dart';
import '../models/customer.dart';
import '../services/guide_service.dart';
import '../services/tripo_service.dart';
import '../services/seedance_service.dart';
import '../services/line_cook_service.dart';
import '../services/customer_service.dart';
import '../services/review_service.dart';
import '../services/elevenlabs_service.dart';
import '../services/gemini_image_service.dart';
import '../services/debug_logger.dart';

class ApiTestScreen extends StatefulWidget {
  const ApiTestScreen({super.key});

  @override
  State<ApiTestScreen> createState() => _ApiTestScreenState();
}

class _ApiTestScreenState extends State<ApiTestScreen> {
  // Services
  final GuideService _guideService = GuideService();
  final TripoService _tripoService = TripoService();
  final SeedanceService _seedanceService = SeedanceService();
  final LineCookService _lineCookService = LineCookService();
  final CustomerService _customerService = CustomerService();
  final ReviewService _reviewService = ReviewService();
  final ElevenLabsService _elevenLabsService = ElevenLabsService();
  final GeminiImageService _geminiImageService = GeminiImageService();
  final DebugLogger _log = DebugLogger.instance;

  // Image
  Uint8List? _selectedImageBytes;
  final ImagePicker _picker = ImagePicker();

  // Section 1 — GuideService state
  bool _identifyLoading = false;
  String? _identifyResult;
  String? _identifyError;
  bool _chatLoading = false;
  String? _chatResult;
  String? _chatError;
  bool _recipeLoading = false;
  Recipe? _recipeResult;
  String? _recipeError;
  final TextEditingController _chatController = TextEditingController();

  // Section 2 — TripoService state
  bool _tripoMockLoading = false;
  bool _tripoLiveLoading = false;
  String? _tripoTaskId;
  String? _tripoGlbUrl;
  String? _tripoStatus;
  String? _tripoError;

  // Section 3 — LineCookService state
  bool _chefLoading = false;
  LineCook? _chefResult;
  String? _chefError;

  // Section 4 — CustomerService state
  bool _customerLoading = false;
  List<Customer>? _customerResult;
  String? _customerError;

  // Section 5 — ReviewService state
  bool _reviewHighLoading = false;
  String? _reviewHighResult;
  String? _reviewHighError;
  bool _reviewLowLoading = false;
  String? _reviewLowResult;
  String? _reviewLowError;

  // Section 6 — SeedanceService state (multi-video: 3 steps + serving)
  bool _seedanceLiveLoading = false;
  String? _seedanceError;
  // Each slot: "step_0", "step_1", "step_2", "serving"
  final Map<String, String> _seedanceStatuses = {};
  final Map<String, String?> _seedanceVideoUrls = {};
  final Map<String, VideoPlayerController?> _videoControllers = {};
  int _seedanceCompleted = 0;
  int _seedanceTotal = 0;

  // Section 7 — ElevenLabs TTS state
  bool _ttsLoading = false;
  Uint8List? _ttsAudioBytes;
  String? _ttsError;
  String? _ttsResult;
  final AudioPlayer _audioPlayer = AudioPlayer();

  // Section 8 — Gemini Image state
  bool _geminiLoading = false;
  Map<String, Uint8List>? _geminiImages;
  String? _geminiError;
  String? _geminiResult;

  @override
  void dispose() {
    _chatController.dispose();
    for (final c in _videoControllers.values) {
      c?.dispose();
    }
    _audioPlayer.dispose();
    super.dispose();
  }

  // ─── Image Picker ───

  Future<void> _pickImage() async {
    try {
      final XFile? file = await _picker.pickImage(source: ImageSource.gallery);
      if (file != null) {
        final bytes = await file.readAsBytes();
        setState(() {
          _selectedImageBytes = bytes;
        });
      }
    } catch (e) {
      setState(() {
        _identifyError = 'Image picker error: $e';
      });
    }
  }

  Future<void> _loadTestPhoto() async {
    try {
      final data = await rootBundle.load('assets/images/tonkotsu_ramen_basic.png');
      setState(() {
        _selectedImageBytes = data.buffer.asUint8List();
      });
    } catch (e) {
      setState(() {
        _identifyError = 'Failed to load test photo: $e';
      });
    }
  }

  // ─── Section 1: GuideService ───

  Future<void> _identifyDish() async {
    if (_selectedImageBytes == null) {
      setState(() => _identifyError = 'Pick a photo first');
      return;
    }
    setState(() {
      _identifyLoading = true;
      _identifyError = null;
      _identifyResult = null;
      _guideService.reset();
    });
    try {
      final result = await _guideService.identifyDish(_selectedImageBytes!);
      _log.logSuccess('GuideService', 'identifyDish', result.substring(0, result.length.clamp(0, 120)));
      setState(() => _identifyResult = result);
    } catch (e) {
      _log.logError('GuideService', 'identifyDish', e.toString());
      setState(() => _identifyError = e.toString());
    } finally {
      setState(() => _identifyLoading = false);
    }
  }

  Future<void> _chat() async {
    final msg = _chatController.text.trim();
    if (msg.isEmpty) return;
    setState(() {
      _chatLoading = true;
      _chatError = null;
      _chatResult = null;
    });
    try {
      final result = await _guideService.chat(msg);
      _log.logSuccess('GuideService', 'chat', result.substring(0, result.length.clamp(0, 120)));
      setState(() => _chatResult = result);
    } catch (e) {
      _log.logError('GuideService', 'chat', e.toString());
      setState(() => _chatError = e.toString());
    } finally {
      setState(() => _chatLoading = false);
    }
  }

  Future<void> _generateRecipe() async {
    setState(() {
      _recipeLoading = true;
      _recipeError = null;
      _recipeResult = null;
    });
    try {
      final result = await _guideService.generateRecipe();
      _log.logSuccess('GuideService', 'generateRecipe', '${result.dishName} (${result.steps.length} steps)');
      setState(() => _recipeResult = result);
    } catch (e) {
      _log.logError('GuideService', 'generateRecipe', e.toString());
      setState(() => _recipeError = e.toString());
    } finally {
      setState(() => _recipeLoading = false);
    }
  }

  // ─── Section 2: TripoService ───

  Future<void> _tripoMock() async {
    setState(() {
      _tripoMockLoading = true;
      _tripoError = null;
      _tripoTaskId = 'mock_masuzushi';
      _tripoGlbUrl = null;
      _tripoStatus = 'Starting mock poll...';
    });

    _log.logInfo('TripoService', 'Starting mock poll for mock_masuzushi');
    _tripoService.startPollingInBackground('mock_masuzushi', (url) {
      if (mounted) {
        _log.logSuccess('TripoService', 'tripoMock', 'GLB URL: $url');
        setState(() {
          _tripoGlbUrl = url;
          _tripoStatus = 'Complete!';
          _tripoMockLoading = false;
        });
      }
    });
  }

  Future<void> _tripoLive() async {
    if (_selectedImageBytes == null) {
      setState(() => _tripoError = 'Pick a photo in Section 1 first');
      return;
    }
    setState(() {
      _tripoLiveLoading = true;
      _tripoError = null;
      _tripoTaskId = null;
      _tripoGlbUrl = null;
      _tripoStatus = 'Uploading image...';
    });
    try {
      final taskId = await _tripoService.startGeneration(_selectedImageBytes!);
      _log.logSuccess('TripoService', 'startGeneration', 'Task ID: $taskId');
      setState(() {
        _tripoTaskId = taskId;
        _tripoStatus = 'Polling task $taskId...';
      });
      _tripoService.startPollingInBackground(taskId, (url) {
        if (mounted) {
          _log.logSuccess('TripoService', 'tripoLive', 'GLB URL: $url');
          setState(() {
            _tripoGlbUrl = url;
            _tripoStatus = 'Complete!';
            _tripoLiveLoading = false;
          });
        }
      }, onError: (err) {
        if (mounted) {
          _log.logError('TripoService', 'tripoLive polling', err);
          setState(() {
            _tripoError = err;
            _tripoStatus = 'Failed';
            _tripoLiveLoading = false;
          });
        }
      }, onStatus: (status) {
        if (mounted) {
          setState(() {
            _tripoStatus = '⏳ $status';
          });
        }
      });
    } catch (e) {
      _log.logError('TripoService', 'tripoLive', e.toString());
      setState(() {
        _tripoError = e.toString();
        _tripoLiveLoading = false;
      });
    }
  }

  // ─── Section 6: SeedanceService (multi-video) ───

  /// Generate all 4 videos: one per step + serving.
  /// Fires them all in parallel.
  Future<void> _seedanceGenerateAll() async {
    final recipe = _recipeResult ?? Recipe.fixture();
    final steps = recipe.steps;

    // Build prompts map: slot key → prompt
    final prompts = <String, String>{};
    for (int i = 0; i < steps.length && i < 3; i++) {
      prompts['step_$i'] = steps[i].seedancePrompt;
    }
    prompts['serving'] = recipe.servingVideoPrompt;

    setState(() {
      _seedanceLiveLoading = true;
      _seedanceError = null;
      _seedanceStatuses.clear();
      _seedanceVideoUrls.clear();
      for (final c in _videoControllers.values) {
        c?.dispose();
      }
      _videoControllers.clear();
      _seedanceCompleted = 0;
      _seedanceTotal = prompts.length;
      for (final key in prompts.keys) {
        _seedanceStatuses[key] = 'Queuing...';
      }
    });

    // Fire each video generation in parallel
    for (final entry in prompts.entries) {
      final slotKey = entry.key;
      final prompt = entry.value;

      _startSingleSeedance(slotKey, prompt);
    }
  }

  Future<void> _startSingleSeedance(String slotKey, String prompt) async {
    try {
      final taskId = await _seedanceService.startGeneration(prompt);
      if (!mounted) return;
      setState(() {
        _seedanceStatuses[slotKey] = 'Polling $taskId...';
      });

      _seedanceService.startPollingInBackground(
        taskId,
        (url) {
          if (!mounted) return;
          setState(() {
            _seedanceVideoUrls[slotKey] = url;
            _seedanceStatuses[slotKey] = '✅ Complete';
            _seedanceCompleted++;
            if (_seedanceCompleted >= _seedanceTotal) {
              _seedanceLiveLoading = false;
            }
          });
          _initVideoPlayerForSlot(slotKey, url);
        },
        onError: (err) {
          if (!mounted) return;
          setState(() {
            _seedanceStatuses[slotKey] = '❌ Failed: $err';
            _seedanceCompleted++;
            if (_seedanceCompleted >= _seedanceTotal) {
              _seedanceLiveLoading = false;
            }
          });
        },
        onStatus: (status) {
          if (!mounted) return;
          setState(() {
            _seedanceStatuses[slotKey] = '⏳ $status';
          });
        },
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _seedanceStatuses[slotKey] = '❌ ${e.toString().substring(0, 60)}';
        _seedanceCompleted++;
        if (_seedanceCompleted >= _seedanceTotal) {
          _seedanceLiveLoading = false;
        }
      });
    }
  }

  void _initVideoPlayerForSlot(String slotKey, String url) {
    _videoControllers[slotKey]?.dispose();
    final controller = url.startsWith('assets/')
        ? VideoPlayerController.asset(url)
        : VideoPlayerController.networkUrl(Uri.parse(url));
    controller.initialize().then((_) {
      if (mounted) {
        setState(() {
          _videoControllers[slotKey] = controller;
          controller.setLooping(true);
          controller.play();
        });
      }
    });
  }

  String _slotLabel(String slotKey) {
    if (slotKey == 'serving') return '🍜 Serving';
    final recipe = _recipeResult ?? Recipe.fixture();
    final idx = int.tryParse(slotKey.replaceFirst('step_', '')) ?? 0;
    if (idx < recipe.steps.length) {
      return '${idx + 1}. ${recipe.steps[idx].name}';
    }
    return 'Step ${idx + 1}';
  }

  // ─── Section 3: LineCookService ───

  Future<void> _generateChef() async {
    setState(() {
      _chefLoading = true;
      _chefError = null;
      _chefResult = null;
    });
    try {
      final result = await _lineCookService.generateChef();
      _log.logSuccess('LineCookService', 'generateChef', '${result.name} — ${result.specialtyRegions.join(", ")}');
      setState(() => _chefResult = result);
    } catch (e) {
      _log.logError('LineCookService', 'generateChef', e.toString());
      setState(() => _chefError = e.toString());
    } finally {
      setState(() => _chefLoading = false);
    }
  }

  // ─── Section 4: CustomerService ───

  Future<void> _generateQueue() async {
    setState(() {
      _customerLoading = true;
      _customerError = null;
      _customerResult = null;
    });
    try {
      // Use fixture recipe as current menu
      final fixtureMenu = [Recipe.fixture()];
      final result = await _customerService.generateQueue(fixtureMenu);
      _log.logSuccess('CustomerService', 'generateQueue', '${result.length} customers generated');
      setState(() => _customerResult = result);
    } catch (e) {
      _log.logError('CustomerService', 'generateQueue', e.toString());
      setState(() => _customerError = e.toString());
    } finally {
      setState(() => _customerLoading = false);
    }
  }

  // ─── Section 5: ReviewService ───

  Future<void> _getReviewHigh() async {
    setState(() {
      _reviewHighLoading = true;
      _reviewHighError = null;
      _reviewHighResult = null;
    });
    try {
      final result = await _reviewService.getReview(
        'Yuki',
        'Hakata Tonkotsu Ramen',
        'Fukuoka',
        0.9,
      );
      _log.logSuccess('ReviewService', 'getReview(high)', result.substring(0, result.length.clamp(0, 80)));
      setState(() => _reviewHighResult = result);
    } catch (e) {
      _log.logError('ReviewService', 'getReview(high)', e.toString());
      setState(() => _reviewHighError = e.toString());
    } finally {
      setState(() => _reviewHighLoading = false);
    }
  }

  Future<void> _getReviewLow() async {
    setState(() {
      _reviewLowLoading = true;
      _reviewLowError = null;
      _reviewLowResult = null;
    });
    try {
      final result = await _reviewService.getReview(
        'Marco',
        'Hakata Tonkotsu Ramen',
        'Fukuoka',
        0.2,
      );
      _log.logSuccess('ReviewService', 'getReview(low)', result.substring(0, result.length.clamp(0, 80)));
      setState(() => _reviewLowResult = result);
    } catch (e) {
      _log.logError('ReviewService', 'getReview(low)', e.toString());
      setState(() => _reviewLowError = e.toString());
    } finally {
      setState(() => _reviewLowLoading = false);
    }
  }

  // ─── Section 7: ElevenLabs TTS ───

  Future<void> _generateTTS() async {
    final text = _identifyResult ??
        'Ah, what a magnificent bowl! This is Hakata Tonkotsu Ramen, '
        'born in the bustling yatai stalls of Fukuoka. The creamy, '
        'milky-white pork bone broth has been simmered for eighteen hours.';

    setState(() {
      _ttsLoading = true;
      _ttsError = null;
      _ttsResult = null;
      _ttsAudioBytes = null;
    });

    try {
      final bytes = await _elevenLabsService.generateSpeech(text);
      if (bytes != null) {
        _log.logSuccess('ElevenLabs', 'generateSpeech', '${bytes.length} bytes');
        setState(() {
          _ttsAudioBytes = bytes;
          _ttsResult = 'Generated ${bytes.length} bytes of audio';
        });
      } else {
        _log.logError('ElevenLabs', 'generateSpeech', 'returned null');
        setState(() {
          _ttsError = 'ElevenLabs returned null — check API key';
        });
      }
    } catch (e) {
      _log.logError('ElevenLabs', 'generateSpeech', e.toString());
      setState(() => _ttsError = e.toString());
    } finally {
      setState(() => _ttsLoading = false);
    }
  }

  Future<void> _playTTS() async {
    if (_ttsAudioBytes == null) return;
    try {
      await _audioPlayer.play(BytesSource(_ttsAudioBytes!));
    } catch (e) {
      setState(() => _ttsError = 'Playback error: $e');
    }
  }

  Future<void> _stopTTS() async {
    await _audioPlayer.stop();
  }

  // ─── Section 8: Gemini Images ───

  Future<void> _generateIngredientImages() async {
    final ingredients = _recipeResult?.ingredients.map((i) => i.name).toList() ??
        ['chashu pork', 'ajitama egg', 'nori seaweed'];

    setState(() {
      _geminiLoading = true;
      _geminiError = null;
      _geminiResult = null;
      _geminiImages = null;
    });

    try {
      final images = await _geminiImageService.generateIngredientImages(
        ingredients,
        maxCount: 3,
      );
      if (images.isEmpty) {
        _log.logError('GeminiImage', 'generateIngredientImages', 'empty result');
        setState(() {
          _geminiError = 'No images generated — Gemini may not support image '
              'generation on this model. Check API key and model.';
        });
      } else {
        _log.logSuccess('GeminiImage', 'generateIngredientImages', '${images.length} images');
        setState(() {
          _geminiImages = images;
          _geminiResult = 'Generated ${images.length} ingredient images';
        });
      }
    } catch (e) {
      _log.logError('GeminiImage', 'generateIngredientImages', e.toString());
      setState(() => _geminiError = e.toString());
    } finally {
      setState(() => _geminiLoading = false);
    }
  }

  // ─── Build ───

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('🧪 API Test Screen'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSection1(),
            const Divider(height: 40, thickness: 2),
            _buildSection7(),
            const Divider(height: 40, thickness: 2),
            _buildSection8(),
            const Divider(height: 40, thickness: 2),
            _buildSection6(),
            const Divider(height: 40, thickness: 2),
            _buildSection2(),
            const Divider(height: 40, thickness: 2),
            _buildSection3(),
            const Divider(height: 40, thickness: 2),
            _buildSection4(),
            const Divider(height: 40, thickness: 2),
            _buildSection5(),
            const Divider(height: 40, thickness: 2),
            _buildLogSection(),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  // ─── Section 1: GuideService ───

  Widget _buildSection1() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '§1 — GuideService (Claude)',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),

        // Image picker
        Row(
          children: [
            ElevatedButton.icon(
              onPressed: _pickImage,
              icon: const Icon(Icons.photo_library),
              label: const Text('Pick Photo'),
            ),
            const SizedBox(width: 8),
            ElevatedButton.icon(
              onPressed: _loadTestPhoto,
              icon: const Icon(Icons.ramen_dining),
              label: const Text('Load Test Ramen'),
            ),
          ],
        ),
        if (_selectedImageBytes != null) ...[
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.memory(
              _selectedImageBytes!,
              height: 150,
              fit: BoxFit.cover,
            ),
          ),
        ],
        const SizedBox(height: 12),

        // Identify dish
        _buildActionButton(
          label: 'Identify Dish',
          loading: _identifyLoading,
          onPressed: _identifyDish,
        ),
        _buildResultText(_identifyResult),
        _buildErrorText(_identifyError),
        const SizedBox(height: 12),

        // Chat follow-up
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _chatController,
                decoration: const InputDecoration(
                  hintText: 'Follow-up question...',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
            ),
            const SizedBox(width: 8),
            _buildActionButton(
              label: 'Ask',
              loading: _chatLoading,
              onPressed: _chat,
            ),
          ],
        ),
        _buildResultText(_chatResult),
        _buildErrorText(_chatError),
        const SizedBox(height: 12),

        // Generate recipe
        _buildActionButton(
          label: 'Generate Recipe',
          loading: _recipeLoading,
          onPressed: _generateRecipe,
        ),
        _buildErrorText(_recipeError),
        if (_recipeResult != null) _buildRecipeCard(_recipeResult!),
      ],
    );
  }

  Widget _buildRecipeCard(Recipe r) {
    return Card(
      margin: const EdgeInsets.only(top: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('🍽 ${r.dishName}',
                style: const TextStyle(
                    fontSize: 18, fontWeight: FontWeight.bold)),
            Text('Region: ${r.region} / ${r.prefecture}'),
            Text('Rarity: ${r.rarity}'),
            Text('Tags: ${r.flavorTags.join(", ")}'),
            const SizedBox(height: 8),
            Text('Teaser: ${r.teaser}',
                style: const TextStyle(fontStyle: FontStyle.italic)),
            const SizedBox(height: 8),
            const Text('Ingredients (3):',
                style: TextStyle(fontWeight: FontWeight.bold)),
            ...r.ingredients.map((i) => Text('  • ${i.name}: ${i.amount}')),
            const SizedBox(height: 8),
            const Text('Prep Steps (3):',
                style: TextStyle(fontWeight: FontWeight.bold)),
            ...r.steps.asMap().entries.map((entry) {
              final idx = entry.key + 1;
              final s = entry.value;
              return Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('  $idx. ${s.name}',
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                    Text('     ${s.description}',
                        style: const TextStyle(fontSize: 12)),
                    Text('     🎬 ${s.seedancePrompt}',
                        style: const TextStyle(
                            fontSize: 10, color: Colors.deepOrange)),
                  ],
                ),
              );
            }),
            const SizedBox(height: 8),
            const Text('Serving Video Prompt:',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
            Text('🎬 ${r.servingVideoPrompt}',
                style: const TextStyle(fontSize: 10, color: Colors.deepOrange)),
            const SizedBox(height: 8),
            Text('Tripo prompt: ${r.tripoPrompt}',
                style: const TextStyle(fontSize: 11, color: Colors.grey)),
            const SizedBox(height: 8),
            ExpansionTile(
              title: const Text('Long Description',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
              tilePadding: EdgeInsets.zero,
              childrenPadding: const EdgeInsets.only(bottom: 8),
              children: [
                Text(r.longDescription,
                    style: const TextStyle(fontSize: 12, height: 1.5)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ─── Section 2: TripoService ───

  Widget _buildSection2() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '§2 — TripoService (3D Model)',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            _buildActionButton(
              label: 'Start (mock)',
              loading: _tripoMockLoading,
              onPressed: _tripoMock,
            ),
            const SizedBox(width: 8),
            _buildActionButton(
              label: 'Start (live)',
              loading: _tripoLiveLoading,
              onPressed: _tripoLive,
            ),
          ],
        ),
        if (_tripoTaskId != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text('Task ID: $_tripoTaskId'),
          ),
        if (_tripoStatus != null)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text('Status: $_tripoStatus'),
          ),
        _buildErrorText(_tripoError),
        if (_tripoGlbUrl != null) ...[
          const SizedBox(height: 8),
          Text('GLB URL: $_tripoGlbUrl'),
          const SizedBox(height: 8),
          SizedBox(
            height: 300,
            child: Flutter3DViewer(
              src: _tripoGlbUrl!,
            ),
          ),
        ],
      ],
    );
  }

  // ─── Section 3: LineCookService ───

  Widget _buildSection3() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '§3 — LineCookService (Claude)',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        _buildActionButton(
          label: 'Generate Chef',
          loading: _chefLoading,
          onPressed: _generateChef,
        ),
        _buildErrorText(_chefError),
        if (_chefResult != null) _buildChefCard(_chefResult!),
      ],
    );
  }

  Widget _buildChefCard(LineCook c) {
    return Card(
      margin: const EdgeInsets.only(top: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('👨‍🍳 ${c.name}',
                style: const TextStyle(
                    fontSize: 18, fontWeight: FontWeight.bold)),
            Text('Regions: ${c.specialtyRegions.join(", ")}'),
            Text('Strengths: ${c.strengthTags.join(", ")}'),
            Text('Weaknesses: ${c.weaknessTags.join(", ")}'),
            Text('Personality: ${c.personality}'),
            Text('Backstory: ${c.backstory}'),
          ],
        ),
      ),
    );
  }

  // ─── Section 4: CustomerService ───

  Widget _buildSection4() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '§4 — CustomerService (Claude)',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        _buildActionButton(
          label: 'Generate Queue',
          loading: _customerLoading,
          onPressed: _generateQueue,
        ),
        _buildErrorText(_customerError),
        if (_customerResult != null)
          ...(_customerResult!.map(_buildCustomerCard)),
      ],
    );
  }

  Widget _buildCustomerCard(Customer c) {
    return Card(
      margin: const EdgeInsets.only(top: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('🧑 ${c.name}',
                style: const TextStyle(
                    fontSize: 16, fontWeight: FontWeight.bold)),
            Text('Type: ${c.type}'),
            Text('Desires: ${c.desires.join(", ")}'),
            Text('Budget: ${c.budget}'),
          ],
        ),
      ),
    );
  }

  // ─── Section 5: ReviewService ───

  Widget _buildSection5() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '§5 — ReviewService (Claude)',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            _buildActionButton(
              label: 'Review (high: 0.9)',
              loading: _reviewHighLoading,
              onPressed: _getReviewHigh,
            ),
            const SizedBox(width: 8),
            _buildActionButton(
              label: 'Review (low: 0.2)',
              loading: _reviewLowLoading,
              onPressed: _getReviewLow,
            ),
          ],
        ),
        _buildResultText(_reviewHighResult),
        _buildErrorText(_reviewHighError),
        _buildResultText(_reviewLowResult),
        _buildErrorText(_reviewLowError),
      ],
    );
  }

  // ─── Section 6: SeedanceService (multi-video) ───

  Widget _buildSection6() {
    final recipe = _recipeResult ?? Recipe.fixture();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '§6 — SeedanceService (BytePlus Video)',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        Text(
          'Generates ${recipe.steps.length} step videos + 1 serving video = ${recipe.steps.length + 1} total',
          style: const TextStyle(fontSize: 12, color: Colors.grey),
        ),
        const SizedBox(height: 12),
        _buildActionButton(
          label: _seedanceLiveLoading
              ? 'Generating ($_seedanceCompleted/$_seedanceTotal)...'
              : 'Generate All Videos (live)',
          loading: _seedanceLiveLoading,
          onPressed: _seedanceGenerateAll,
        ),
        _buildErrorText(_seedanceError),
        const SizedBox(height: 8),

        // Status list for all slots
        if (_seedanceStatuses.isNotEmpty)
          ...(_seedanceStatuses.entries.map((entry) {
            final slotKey = entry.key;
            final status = entry.value;
            final videoUrl = _seedanceVideoUrls[slotKey];
            final controller = _videoControllers[slotKey];
            final label = _slotLabel(slotKey);

            return Card(
              margin: const EdgeInsets.only(top: 8),
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label,
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 14)),
                    Text('Status: $status',
                        style: const TextStyle(fontSize: 12)),
                    if (videoUrl != null) ...[
                      const SizedBox(height: 4),
                      Text('URL: $videoUrl',
                          style: const TextStyle(
                              fontSize: 10, color: Colors.grey)),
                      const SizedBox(height: 8),
                      if (controller != null &&
                          controller.value.isInitialized)
                        AspectRatio(
                          aspectRatio: controller.value.aspectRatio,
                          child: VideoPlayer(controller),
                        )
                      else
                        const Text('Loading video player...',
                            style: TextStyle(fontSize: 11)),
                    ],
                  ],
                ),
              ),
            );
          })),
      ],
    );
  }

  // ─── Section 7: ElevenLabs TTS ───

  Widget _buildSection7() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '§7 — ElevenLabs TTS (Audio)',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        Text(
          _identifyResult != null
              ? 'Will speak the guide output from §1'
              : 'Will speak a sample ramen narration (run §1 first for live text)',
          style: const TextStyle(fontSize: 12, color: Colors.grey),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            _buildActionButton(
              label: 'Generate Speech',
              loading: _ttsLoading,
              onPressed: _generateTTS,
            ),
            const SizedBox(width: 8),
            if (_ttsAudioBytes != null) ...[
              IconButton(
                onPressed: _playTTS,
                icon: const Icon(Icons.play_arrow, color: Colors.green),
                tooltip: 'Play',
              ),
              IconButton(
                onPressed: _stopTTS,
                icon: const Icon(Icons.stop, color: Colors.red),
                tooltip: 'Stop',
              ),
            ],
          ],
        ),
        _buildResultText(_ttsResult),
        _buildErrorText(_ttsError),
      ],
    );
  }

  // ─── Section 8: Gemini Images ───

  Widget _buildSection8() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '§8 — Gemini (Ingredient Images)',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        Text(
          _recipeResult != null
              ? 'Will generate images for recipe ingredients from §1'
              : 'Will use default ingredients: chashu pork, ajitama egg, nori',
          style: const TextStyle(fontSize: 12, color: Colors.grey),
        ),
        const SizedBox(height: 12),
        _buildActionButton(
          label: 'Generate Ingredient Images',
          loading: _geminiLoading,
          onPressed: _generateIngredientImages,
        ),
        _buildResultText(_geminiResult),
        _buildErrorText(_geminiError),
        if (_geminiImages != null && _geminiImages!.isNotEmpty) ...[
          const SizedBox(height: 12),
          SizedBox(
            height: 160,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: _geminiImages!.entries.map((entry) {
                return Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: Column(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.memory(
                          entry.value,
                          height: 120,
                          width: 120,
                          fit: BoxFit.cover,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        entry.key,
                        style: const TextStyle(fontSize: 11),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ],
    );
  }



  // ─── Log Section ───

  Widget _buildLogSection() {
    final entries = _log.entries;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '📋 Debug Log',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            ElevatedButton.icon(
              onPressed: () async {
                await _log.copyToClipboard();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Copied ${entries.length} log entries to clipboard'),
                      duration: const Duration(seconds: 2),
                    ),
                  );
                }
              },
              icon: const Icon(Icons.copy, size: 16),
              label: Text('Copy All (${entries.length})'),
            ),
            const SizedBox(width: 8),
            ElevatedButton.icon(
              onPressed: () {
                setState(() => _log.clear());
              },
              icon: const Icon(Icons.delete_outline, size: 16),
              label: const Text('Clear'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (entries.isEmpty)
          const Text('No log entries yet. Run some tests!',
              style: TextStyle(color: Colors.grey)),
        if (entries.isNotEmpty)
          Container(
            width: double.infinity,
            constraints: const BoxConstraints(maxHeight: 300),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.grey.withAlpha(20),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: Colors.grey.withAlpha(60)),
            ),
            child: SingleChildScrollView(
              reverse: true, // auto-scroll to newest
              child: SelectableText(
                entries.join('\n'),
                style: const TextStyle(fontSize: 11, fontFamily: 'monospace'),
              ),
            ),
          ),
      ],
    );
  }

  // ─── Shared widgets ───

  Widget _buildActionButton({
    required String label,
    required bool loading,
    required VoidCallback onPressed,
  }) {
    return ElevatedButton(
      onPressed: loading ? null : onPressed,
      child: loading
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Text(label),
    );
  }

  Widget _buildResultText(String? text) {
    if (text == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.green.withAlpha(30),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: Colors.green.withAlpha(80)),
        ),
        child: SelectableText(
          text,
          style: const TextStyle(fontSize: 13),
        ),
      ),
    );
  }

  Widget _buildErrorText(String? text) {
    if (text == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.red.withAlpha(30),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: Colors.red.withAlpha(80)),
        ),
        child: SelectableText(
          text,
          style: const TextStyle(fontSize: 13, color: Colors.redAccent),
        ),
      ),
    );
  }
}
