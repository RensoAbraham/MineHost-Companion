use reqwest::Client;
use serde::Deserialize;
use std::error::Error;
use std::path::Path;

use std::fs::{create_dir_all, File as StdFile, remove_file};
use std::io::{Read, Write};

use sha2::{Digest, Sha256}; 

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

pub async fn download_paper_server(
    client: &Client,
    version: &str,
    save_path: &Path,
) -> Result<String, Box<dyn Error>> {
    
    println!("[Downloader] Iniciando descarga de PaperMC versión {}", version);

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