{
    "dialogue": {
        "satellite_site_ids": "motox,buero,büro,Küche",
        "system": "rhasspy",
        "volume": "1"
    },
    "intent": {
        "lang": "de",
        "satellite_site_ids": "motox,buero,büro,Küche,defhem",
        "system": "fsticuffs"
    },
    "mqtt": {
        "enabled": ""
    },
    "sounds": {
        "error": "${RHASSPY_PROFILE_DIR}/sounds/error.wav",
        "recorded": "${RHASSPY_PROFILE_DIR}/sounds/end_of_input.wav",
        "wake": "${RHASSPY_PROFILE_DIR}/sounds/start_of_input.wav"
    },
    "speech_to_text": {
        "satellite_site_ids": "motox,buero,büro,Küche",
        "system": "kaldi"
    },
    "text_to_speech": {
        "larynx": {
            "vocoder": "vctk_small"
        },
        "nanotts": {
            "volume": "2"
        },
        "satellite_site_ids": "motox,buero,büro,Küche",
        "system": "nanotts"
    },
    "wake": {
        "porcupine": {
            "keyword_path": "bumblebee_linux.ppn",
            "udp_audio": "0.0.0.0:12199:motox"
        },
        "satellite_site_ids": "motox,buero,büro,Küche",
        "snowboy": {
            "apply_frontend": true,
            "model": "alexa.umdl",
            "sensitivity": "0.6",
            "udp_audio": "0.0.0.0:12199:motox"
        },
        "system": "porcupine"
    }
}
