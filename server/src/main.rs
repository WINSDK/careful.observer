use axum::body::Body;
use axum::extract::{State, Request};
use axum::http::StatusCode;
use axum::response::{IntoResponse, Response};
use axum::routing::get;

use tower::ServiceBuilder;
use tower_http::trace::TraceLayer;
use tower_http::services::ServeDir;

use std::fs;
use std::net::SocketAddr;
use std::path::PathBuf;

#[tokio::main]
async fn main() {
    let base_dir = match std::env::var("BASE_DIR") {
        Ok(s) => PathBuf::from(s),
        Err(..) => panic!("Missing BASE_DIR env variable\ndon't know what to host.")
    };

    let port = match std::env::var("PORT") {
        Ok(s) => usize::from_str_radix(&s, 10).expect("Invalid port number") as u16,
        Err(..) => panic!("Missing PORT env variable.")
    };

    let serve_css = ServeDir::new(base_dir.join("css"));
    let serve_assets = ServeDir::new(base_dir.join("assets"));

    let app = axum::Router::new()
        .nest_service("/css", serve_css)
        .nest_service("/assets", serve_assets)
        .fallback(get(serve_html))
        .with_state(base_dir)
        .layer(ServiceBuilder::new().layer(TraceLayer::new_for_http()));

    let addr = SocketAddr::from(([127, 0, 0, 1], port));
    println!("Server running at http://{addr}");

    let listener = tokio::net::TcpListener::bind(addr).await.unwrap();
    axum::serve(listener, app.layer(TraceLayer::new_for_http()))
        .await
        .unwrap();
}

async fn serve_html(State(base_dir): State<PathBuf>, req: Request<Body>) -> impl IntoResponse {
    let content_file = req.uri().path();
    if content_file.ends_with(".html") {
        let content_file = content_file.trim_end_matches(".html");

        return Response::builder()
            .status(StatusCode::MOVED_PERMANENTLY)
            .header("Location", content_file)
            .body(Body::empty())
            .unwrap();
    }

    let content_file = match content_file {
        "/" => "about.html".to_string(),
        path => {
            let mut path = path.strip_prefix("/").unwrap_or(path).to_string();
            if !path.ends_with(".html") {
                path += ".html";
            }
            path
        }
    };

    let content_path = base_dir.join(content_file);
    let Ok(mut content) = fs::read_to_string(&content_path) else {
        return Response::builder()
            .status(StatusCode::NOT_FOUND)
            .body(Body::from("File not found"))
            .unwrap();
    };

    // If htmx does a AJAX request then don't provide the full body, just the component.
    if !req.headers().contains_key("hx-request") {
        let index_path = base_dir.join("index.html");
        let Ok(index) = fs::read_to_string(&index_path) else {
            return Response::builder()
                .status(StatusCode::INTERNAL_SERVER_ERROR)
                .body(Body::from("Internal Server Error"))
                .unwrap();
        };

        // Replace placeholder with actual content.
        content = index.replace("{{ content-body }}", &content);
    }

    // Return the modified HTML.
    Response::builder()
        .status(StatusCode::OK)
        .header("Content-Type", "text/html")
        .body(Body::from(content))
        .unwrap()
}
