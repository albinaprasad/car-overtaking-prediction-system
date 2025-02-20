from fastapi import FastAPI, Response
import json

app = FastAPI()

# Example custom style JSON. Modify this to match your map style.
custom_style = {
    "version": 8,
    "name": "My Custom Style",
    "sources": {
        "osm": {
            "type": "vector",
            "tiles": [
                "https://tile.openstreetmap.org/{z}/{x}/{y}.png"

            ],
            "minzoom": 0,
            "maxzoom": 14
        }
    },
    "layers":
    [
        {
            "id": "background",
            "type": "background",
            "paint": {
                "background-color": "#e0e0e0"
            }
        },
        {
            "id": "buildings",
            "type": "fill-extrusion",
            "source": "osm",
            "source-layer": "building",
            "minzoom": 15,
            "paint": {
                "fill-extrusion-color": "#aaa",
                "fill-extrusion-height": ["get", "height"],
                "fill-extrusion-base": 0,
                "fill-extrusion-opacity": 0.6
            }
        }
        
    ]
}

@app.get("/style.json")
async def get_style():
    # Return the custom style with the correct MIME type.
    return Response(content=json.dumps(custom_style), media_type="application/json")
