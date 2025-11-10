use axum::{
    extract::State,
    routing::{get, post}, // ¡Correcto!
    Json,
    Router,
};
use serde::{Deserialize, Serialize}; // ¡Correcto!
use std::net::SocketAddr;
use std::process::Stdio; // ¡Necesario para start_server!
use std::sync::Arc;
use std::path::Path; 
use tokio::io::AsyncWriteExt; // ¡Necesario para stop_server!
use tokio::net::TcpListener;
use tokio::process::{Child, ChildStdin, Command}; // ¡Necesario para start_server!
use tokio::sync::Mutex;
use tokio::task::JoinHandle; 
use reqwest::Client;
use tower_http::cors::CorsLayer;

// --- Importamos nuestro módulo downloader ---
pub mod downloader;

// --- 1. Definimos el Estado de nuestra Aplicación ---
struct AppState {
    is_minecraft_running: bool,
    child_stdin: Option<ChildStdin>,
    server_monitor_handle: Option<JoinHandle<()>>,
    http_client: Client,
}

// --- 2. Definimos las Estructuras de la API ---
#[derive(Serialize)]
struct StatusResponse { status: String }
#[derive(Serialize)]
struct StartResponse { message: String }
#[derive(Serialize)]
struct StopResponse { message: String }
#[derive(Serialize)]
struct InstallResponse {
    message: String,
    hash: Option<String>,
}

#[derive(Deserialize)]
struct InstallRequest {
    tipo_servidor: ServerType,
    version: String,
}

#[derive(Deserialize, Debug)]
#[serde(rename_all = "lowercase")] 
enum ServerType {
    Paper,
    Fabric,
}

// --- 3. El Main (con ruta POST /install) ---
#[tokio::main]
async fn main() {
    let app_http_client = Client::new();
    let app_state = AppState {
        is_minecraft_running: false,
        child_stdin: None,
        server_monitor_handle: None, 
        http_client: app_http_client,
    };
    
    let shared_state = Arc::new(Mutex::new(app_state));

    let app = Router::new()
        .route("/status", get(get_status))
        .route("/start", get(start_server))
        .route("/stop", get(stop_server))
        .route("/install", post(install_server)) // ¡Correcto!
        .layer(CorsLayer::permissive())
        .with_state(shared_state);

    let addr = SocketAddr::from(([127, 0, 0, 1], 8000));
    println!("Servidor backend (con POST /install) escuchando en http://{}", addr);

    let listener = TcpListener::bind(addr).await.unwrap();
    axum::serve(listener, app.into_make_service())
        .await
        .unwrap();
}

// --- ¡NUEVO! Handler para POST /install ---
async fn install_server(
    State(state): State<Arc<Mutex<AppState>>>,
    Json(request): Json<InstallRequest>, 
) -> Json<InstallResponse> {
    
    let app_state = state.lock().await;
    println!("[Handler /install] Recibida petición para: {:?} v{}", request.tipo_servidor, request.version);

    match request.tipo_servidor {
        ServerType::Paper => {
            let save_path = Path::new("minecraft_server/server.jar");
            match downloader::download_paper_server(&app_state.http_client, &request.version, save_path).await {
                Ok(hash) => Json(InstallResponse {
                    message: "install_success_paper".to_string(),
                    hash: Some(hash),
                }),
                Err(e) => Json(InstallResponse {
                    message: format!("install_failed: {}", e.to_string()),
                    hash: None,
                }),
            }
        }
        
        ServerType::Fabric => {
            let save_path = Path::new("minecraft_server/fabric-installer.jar");
            match downloader::download_fabric_installer(&app_state.http_client, &request.version, save_path).await {
                Ok(_) => Json(InstallResponse {
                    message: "install_success_fabric_installer".to_string(),
                    hash: None,
                }),
                Err(e) => Json(InstallResponse {
                    message: format!("install_failed: {}", e.to_string()),
                    hash: None,
                }),
            }
        }
    }
}


// --- 4. Handler de /status (¡CÓDIGO COMPLETO!) ---
async fn get_status(
    State(state): State<Arc<Mutex<AppState>>>,
) -> Json<StatusResponse> {
    let app_state = state.lock().await;
    let status_str = if app_state.is_minecraft_running { "running" } else { "stopped" };
    Json(StatusResponse { status: status_str.to_string() })
}

// --- 5. Handler para /start (¡CÓDIGO COMPLETO!) ---
async fn start_server(
    State(state): State<Arc<Mutex<AppState>>>,
) -> Json<StartResponse> {
    let mut app_state = state.lock().await;
    if app_state.is_minecraft_running {
        return Json(StartResponse { message: "already_running".to_string() });
    }
    let mut cmd = Command::new("java");
    cmd.args(["-jar", "server.jar", "nogui"]);
    cmd.current_dir("minecraft_server");
    cmd.stdin(Stdio::piped());

    let mut child = match cmd.spawn() {
        Ok(child) => child,
        Err(e) => {
            println!("[Handler /start] Error al hacer spawn del servidor: {}", e);
            return Json(StartResponse { message: "error_spawning".to_string() });
        }
    };
    let stdin = child.stdin.take().expect("¡Error! No se pudo capturar STDIN.");
    let state_clone = Arc::clone(&state);
    let monitor_handle = tokio::spawn(async move {
        monitor_server_process(state_clone, child).await;
    });
    app_state.is_minecraft_running = true;
    app_state.child_stdin = Some(stdin);
    app_state.server_monitor_handle = Some(monitor_handle);
    Json(StartResponse { message: "starting".to_string() })
}

// --- 6. Handler para /stop (¡CÓDIGO COMPLETO!) ---
async fn stop_server(
    State(state): State<Arc<Mutex<AppState>>>,
) -> Json<StopResponse> {
    let mut app_state = state.lock().await;
    if !app_state.is_minecraft_running {
        return Json(StopResponse { message: "already_stopped".to_string() });
    }
    if let Some(mut stdin) = app_state.child_stdin.take() {
        println!("[Handler /stop] Enviando comando 'stop' a STDIN...");
        if let Err(e) = stdin.write_all(b"stop\n").await {
            println!("[Handler /stop] Error al escribir en STDIN: {}", e);
            if let Some(handle) = app_state.server_monitor_handle.take() {
                handle.abort(); 
            }
            app_state.is_minecraft_running = false;
            return Json(StopResponse { message: "error_stopping".to_string() });
        }
        app_state.server_monitor_handle.take(); 
        Json(StopResponse { message: "stopping_gracefully".to_string() })
    } else {
        app_state.is_minecraft_running = false;
        app_state.server_monitor_handle.take();
        Json(StopResponse { message: "error_no_stdin".to_string() })
    }
}

// --- 7. Tarea de Monitoreo (¡CÓDIGO COMPLETO!) ---
async fn monitor_server_process(state: Arc<Mutex<AppState>>, mut child: Child) {
    println!("[Monitor] Tarea de monitoreo iniciada.");
    match child.wait().await {
        Ok(status) => println!("[Monitor] Proceso de Minecraft terminado con estado: {}", status),
        Err(e) => println!("[Monitor] Error al esperar el proceso hijo: {}", e),
    }
    println!("[Monitor] Limpiando estado...");
    let mut app_state = state.lock().await;
    app_state.is_minecraft_running = false;
    app_state.child_stdin = None;
    app_state.server_monitor_handle = None;
}