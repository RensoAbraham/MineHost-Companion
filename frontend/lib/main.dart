import 'package.flutter/material.dart';
import 'package:dio/dio.dart';

// ¡NUEVO! Definimos el Enum aquí en Dart,
// debe coincidir con el 'enum' de Rust
enum ServerType {
  paper,
  fabric,
}

void main() {
  runApp(const MineHostCompanionApp());
}

class MineHostCompanionApp extends StatelessWidget {
  const MineHostCompanionApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
      ),
      home: const DashboardPage(),
    );
  }
}

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  // --- Estado de la UI ---
  String _serverStatus = "Presiona 'Status' para actualizar";
  String _installStatus = "";
  bool _isLoading = false;

  // ¡NUEVO! Estado para los nuevos campos de instalación
  ServerType _selectedServerType = ServerType.paper; // Valor por defecto
  final _versionController = TextEditingController(text: "1.20.1"); // Controlador para el campo de texto

  final _dio = Dio(BaseOptions(baseUrl: 'http://localhost:8000'));

  // ¡NUEVO! Limpiamos el controlador cuando el widget se destruye
  @override
  void dispose() {
    _versionController.dispose();
    super.dispose();
  }

  // --- Funciones de la API ---

  Future<void> _installServer() async {
    setState(() {
      _isLoading = true;
      _installStatus = "Instalando ${_selectedServerType.name} ${_versionController.text}...";
    });

    try {
      // ¡NUEVO! Preparamos el JSON para enviar
      final Map<String, dynamic> requestData = {
        // 'name' nos da el string "paper" o "fabric"
        "tipo_servidor": _selectedServerType.name,
        "version": _versionController.text,
      };

      // ¡NUEVO! Hacemos una petición POST con los datos
      final response = await _dio.post('/install', data: requestData);
      
      if (response.data['message'].contains('install_success')) {
        final String hash = response.data['hash'] ?? ""; // Maneja si el hash es nulo
        setState(() {
          _installStatus = "¡Instalación exitosa! (${response.data['message']})";
          _isLoading = false;
        });
      } else {
        setState(() {
          _installStatus = "Error: ${response.data['message']}";
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _installStatus = "Error: ¿Backend está apagado?";
        _isLoading = false;
      });
      print(e);
    }
  }

  // ... (Las funciones _fetchStatus, _startServer, y _stopServer no cambian) ...
  //region (Funciones sin cambios)
  Future<void> _fetchStatus() async {
    setState(() {
      _isLoading = true;
      _serverStatus = "Actualizando...";
    });

    try {
      final response = await _dio.get('/status');
      final String status = response.data['status'];
      
      setState(() {
        _serverStatus = status;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _serverStatus = "Error: ¿Backend está apagado?";
        _isLoading = false;
      });
      print(e);
    }
  }

  Future<void> _startServer() async {
    setState(() {
      _isLoading = true;
      _serverStatus = "Iniciando...";
    });
    
    try {
      await _dio.get('/start');
      await Future.delayed(const Duration(seconds: 1));
      _fetchStatus(); 
    } catch (e) {
      setState(() {
        _serverStatus = "Error al iniciar";
        _isLoading = false;
      });
      print(e);
    }
  }

  Future<void> _stopServer() async {
    setState(() {
      _isLoading = true;
      _serverStatus = "Deteniendo...";
    });
    
    try {
      await _dio.get('/stop');
      await Future.delayed(const Duration(seconds: 1));
      _fetchStatus();
    } catch (e) {
      setState(() {
        _serverStatus = "Error al detener";
        _isLoading = false;
      });
      print(e);
    }
  }
  //endregion

  // --- UI (la parte visual) ---
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: const Text('MineHost Companion - Dashboard'),
      ),
      body: SingleChildScrollView(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                
                // --- Sección de Instalación (¡MODIFICADA!) ---
                const Text(
                  'Instalación del Servidor',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.w300),
                ),
                const SizedBox(height: 20),

                // --- ¡NUEVO! Fila de Selección ---
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // --- ¡NUEVO! Dropdown de Tipo de Servidor ---
                    // 'DropdownButton' para elegir el tipo
                    DropdownButton<ServerType>(
                      value: _selectedServerType,
                      // 'onChanged' actualiza el estado cuando el usuario elige
                      onChanged: (ServerType? newValue) {
                        if (newValue != null) {
                          setState(() {
                            _selectedServerType = newValue;
                          });
                        }
                      },
                      // 'items' construye la lista de opciones
                      items: ServerType.values.map((ServerType type) {
                        return DropdownMenuItem<ServerType>(
                          value: type,
                          // 'name' nos da "paper" o "fabric"
                          child: Text(type.name.toUpperCase()),
                        );
                      }).toList(),
                    ),

                    const SizedBox(width: 20),

                    // --- ¡NUEVO! Campo de Texto de Versión ---
                    // 'Expanded' toma el espacio restante
                    Expanded(
                      // 'TextFormField' es un campo de texto con validación
                      child: TextFormField(
                        controller: _versionController, // Conectamos el controlador
                        decoration: const InputDecoration(
                          labelText: 'Versión (ej: 1.20.1)',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // --- Botón de Instalar ---
                ElevatedButton.icon(
                  icon: const Icon(Icons.download),
                  label: const Text('Instalar/Actualizar Servidor'),
                  onPressed: _isLoading ? null : _installServer,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  ),
                ),
                
                // Texto de estado de la instalación
                if (_installStatus.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 10.0),
                    child: Text(
                      _installStatus,
                      style: const TextStyle(fontSize: 16),
                      textAlign: TextAlign.center,
                    ),
                  ),

                // --- Divisor ---
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 20.0),
                  child: Divider(),
                ),

                // --- Sección de Control (sin cambios) ---
                const Text(
                  'Estado del Servidor:',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.w300),
                ),
                
                if (_isLoading && _installStatus.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(16.0),
                    child: CircularProgressIndicator(),
                  )
                else
                  Text(
                    _serverStatus.toUpperCase(),
                    style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
                  ),
                
                const SizedBox(height: 20),

                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    FilledButton.icon(
                      icon: const Icon(Icons.play_arrow),
                      label: const Text('Start'),
                      onPressed: _isLoading ? null : _startServer,
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.green,
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                      ),
                    ),
                    const SizedBox(width: 20),
                    FilledButton.icon(
                      icon: const Icon(Icons.stop),
                      label: const Text('Stop'),
                      onPressed: _isLoading ? null : _stopServer,
                    style: FilledButton.styleFrom(
                        backgroundColor: Colors.red,
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                      ),
                    ),
                  ],
                ),
                
                const SizedBox(height: 20),

                ElevatedButton.icon(
                  icon: const Icon(Icons.refresh),
                  label: const Text('Actualizar Status'),
                  onPressed: _isLoading ? null : _fetchStatus,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}