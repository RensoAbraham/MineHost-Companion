use reqwest::Client;
use serde::Deserialize;
use std::error::Error;
use std::path::Path;

use std::fs::{create_dir_all, File as StdFile, remove_file};
use std::io::{Read, Write};

use sha2::{Digest, Sha256}; 

// --- 1. Structs de la API de PaperMC ---
// (Este es tu código antiguo, ¡está perfecto!)
#[derive(Deserialize)]
struct PaperVersionResponse {
    builds: Vec<i32>,
}

#[derive(Deserialize)]
struct PaperBuildResponse {
    downloads: PaperDownloads,
}

#[derive(Deserialize)]
struct PaperDownloads {
    application: PaperDownloadInfo,
}

#[derive(Deserialize)]
struct PaperDownloadInfo {
    name: String,   // ej: "paper-1.20.1-100.jar"
    sha256: String,
}

// --- 2. Función de Descarga de Paper ---
// (Esta es tu función antigua, ¡está perfecta!)
pub async fn download_paper_server(
    client: &Client,
    version: &str,
    save_path: &Path,
) -> Result<String, Box<dyn Error>> {
    
    println!("[Downloader] Iniciando descarga de PaperMC versión {}", version);

    // ... (Todo el código de Paper se queda aquí, no lo borres) ...
    
    let build_api_url = format!(
        "https://api.papermc.io/v2/projects/paper/versions/{}",
        version
    );
    
    let version_response: PaperVersionResponse = client
        .get(&build_api_url)
        .send()
        .await?
        .json()
        .await?;

    let latest_build = match version_response.builds.last() {
        Some(build) => build,
        None => return Err("No se encontraron builds para esta versión".into()),
    };
    
    println!("[Downloader] Última build encontrada: {}", latest_build);

    let download_info_url = format!(
        "https://api.papermc.io/v2/projects/paper/versions/{}/builds/{}",
        version, latest_build
    );
    
    let build_response: PaperBuildResponse = client
        .get(&download_info_url)
        .send()
        .await?
        .json()
        .await?;

    let download_name = &build_response.downloads.application.name;
    let expected_hash = &build_response.downloads.application.sha256;
    
    println!("[Downloader] Nombre del archivo: {}", download_name);
    
    let download_url = format!(
        "https://api.papermc.io/v2/projects/paper/versions/{}/builds/{}/downloads/{}",
        version, latest_build, download_name
    );

    println!("[Downloader] Descargando desde: {}", download_url);
    
    let file_bytes = client.get(&download_url).send().await?.bytes().await?;

    if let Some(dir_path) = save_path.parent() {
        create_dir_all(dir_path)?;
    }

    println!("[Downloader] Guardando archivo en: {:?}", save_path);
    let mut file = StdFile::create(save_path)?;
    
    file.write_all(&file_bytes)?;
    
    println!("[Downloader] ¡Descarga completada!");

    // --- Verificar el Hash SHA256 ---
    println!("[Downloader] Verificando integridad del archivo...");

    let mut file_to_check = StdFile::open(save_path)?;
    let mut sha256 = Sha256::new();
    let mut buffer = [0; 8192]; 

    loop {
        let bytes_read = file_to_check.read(&mut buffer)?;
        if bytes_read == 0 {
            break; 
        }
        sha256.update(&buffer[..bytes_read]);
    }

    let computed_hash_bytes = sha256.finalize();
    let computed_hash_hex = format!("{:x}", computed_hash_bytes);

    if computed_hash_hex == *expected_hash {
        println!("[Downloader] ¡Verificación exitosa!");
        Ok(expected_hash.clone())
    } else {
        println!("[Downloader] ¡ERROR! Verificación de hash fallida.");
        println!("[Downloader]   Esperado: {}", expected_hash);
        println!("[Downloader]   Recibido: {}", computed_hash_hex);
        
        remove_file(save_path)?;
        
        Err("La verificación del hash falló. Archivo corrupto.".into())
    }
}


// --- 4. Structs de la API de Fabric (¡NUEVO!) ---
// (Este es el código que te pedí que AÑADIERAS)

#[derive(Deserialize)]
struct FabricLoaderResponse {
    // Buscamos la versión "estable"
    #[serde(rename = "loader")] // El JSON usa "loader", no "stable_loader"
    stable_loader: FabricVersion,
}

#[derive(Deserialize)]
struct FabricVersion {
    version: String, // ej: "0.15.11"
}

#[derive(Deserialize)]
struct FabricInstallerResponse {
    url: String, // La URL del .jar del instalador
}

// --- 5. Nueva Función Pública de Descarga (Fabric) (¡NUEVO!) ---
// (Esta es la función que te pedí que AÑADIERAS)
pub async fn download_fabric_installer(
    client: &Client,
    version: &str, // ej: "1.20.1"
    save_path: &Path, // ej: "minecraft_server/fabric-installer.jar"
) -> Result<(), Box<dyn Error>> {
    
    println!("[Downloader] Iniciando descarga del INSTALADOR de Fabric {}", version);

    // --- Paso A: Encontrar el último 'loader' estable ---
    let loader_url = "https://meta.fabricmc.net/v2/versions/loader";
    
    // (Ajuste: la API devuelve una lista de objetos, no un objeto con 'loader')
    // Leemos la respuesta como un Vec (lista) de structs
    let loader_responses: Vec<FabricVersion> =
        client.get(loader_url).send().await?.json().await?;

    // Buscamos la primera versión estable en la lista
    let loader_version = match loader_responses.iter().find(|v| v.version.contains("stable")) {
         // (Simplificación: tomaremos la primera versión estable que encontremos)
         // (En una app real, buscaríamos la más reciente. Esto es un ejemplo)
         // (¡Corrección! La API de Fabric cambió. Vamos a simplificarlo
         //  y tomar la última versión estable del "juego" que buscamos, no del loader.)
        
         // ¡NUEVO PLAN MÁS SIMPLE PARA FABRIC!
         // 1. Obtener la última versión del loader para nuestra versión de juego
         _ => {
            // (Esta lógica es más compleja, vamos a simplificarla al máximo por ahora)
            // (Usaremos una versión de loader 'hardcodeada' para este ejemplo
            // y luego la haremos dinámica)
            "0.15.11" // <--- ¡Valor de ejemplo!
         }
    };
    
    // (¡RE-CORRECCIÓN! La API de Fabric es más simple.
    // Vamos a borrar esa lógica compleja. Mi código anterior estaba mal.)
    
    // --- BORRA EL CÓDIGO DE ARRIBA, USA ESTE ---
    // (Ya lo he arreglado en este bloque de código)
    
    // --- Paso A: Encontrar el último 'loader' estable ---
    // (Esta API es un poco diferente. Vamos a buscar el loader
    //  estable para nuestra versión de juego)
    
    // ¡Ajuste! La API de Fabric es más simple.
    // 1. Obtener el 'loader' estable más reciente para esa versión de MC
    let loader_url = format!("https://meta.fabricmc.net/v2/versions/loader/{}/stable", version);
    let loader_response: Vec<FabricLoaderResponse> = client.get(&loader_url).send().await?.json().await?;

    let loader_version = &loader_response[0].stable_loader.version;

    // --- Paso B: Encontrar la URL del instalador ---
    let installer_url = format!(
        "https://meta.fabricmc.net/v2/versions/installer/{}/{}",
        version, loader_version
    );
    let installer_response: FabricInstallerResponse =
        client.get(&installer_url).send().await?.json().await?;

    let download_url = &installer_response.url;

    // --- Paso C: Descargar y Guardar ---
    println!("[Downloader] Descargando desde: {}", download_url);
    let file_bytes = client.get(download_url).send().await?.bytes().await?;

    if let Some(dir_path) = save_path.parent() {
        create_dir_all(dir_path)?;
    }

    let mut file = StdFile::create(save_path)?;
    file.write_all(&file_bytes)?;
    
    println!("[Downloader] ¡Instalador de Fabric descargado!");
    
    Ok(())
}