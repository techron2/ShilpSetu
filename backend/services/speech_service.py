import os
import io
import wave
import logging
import shutil
import speech_recognition as sr

logger = logging.getLogger(__name__)

# ---------------------------------------------------------------------------
# Ensure pydub can find ffmpeg — check PATH first, then winget install location
# ---------------------------------------------------------------------------
_WINGET_FFMPEG_DIR = os.path.join(
    os.path.expanduser("~"),
    r"AppData\Local\Microsoft\WinGet\Packages",
    r"Gyan.FFmpeg_Microsoft.Winget.Source_8wekyb3d8bbwe",
    r"ffmpeg-9.0.1-full_build\bin"
)

def _find_ffmpeg():
    """Locate ffmpeg binary — check PATH first, then known winget install location."""
    path_ffmpeg = shutil.which("ffmpeg")
    if path_ffmpeg:
        return os.path.dirname(path_ffmpeg)
    if os.path.isfile(os.path.join(_WINGET_FFMPEG_DIR, "ffmpeg.exe")):
        return _WINGET_FFMPEG_DIR
    return None

_ffmpeg_dir = _find_ffmpeg()
if _ffmpeg_dir:
    logger.info(f"ffmpeg found at: {_ffmpeg_dir}")
    # Add to PATH so pydub's subprocess calls can find it
    if _ffmpeg_dir not in os.environ.get("PATH", ""):
        os.environ["PATH"] = _ffmpeg_dir + os.pathsep + os.environ.get("PATH", "")
else:
    logger.warning("ffmpeg NOT found on PATH or in winget packages. "
                    "MP3/OGG/M4A audio conversion will not work. "
                    "Install with: winget install Gyan.FFmpeg")

# Map short language codes to standard speech recognition locales
LANG_LOCALE_MAP = {
    "hi": "hi-IN",
    "mr": "mr-IN",
    "ta": "ta-IN",
    "en": "en-IN",
    "te": "te-IN",
    "bn": "bn-IN",
    "gu": "gu-IN",
}

# Friendly low-literacy error messages
FRIENDLY_ERRORS = {
    "unclear_audio": {
        "hi": "आवाज़ साफ़ सुनाई नहीं दी, कृपया दोबारा बोलें।",
        "en": "Could not hear audio clearly, please speak again.",
        "mr": "आवाज स्पष्ट ऐकू आली नाही, कृपया पुन्हा बोला.",
        "ta": "குரல் தெளிவாக கேட்கவில்லை, மீண்டும் பேசவும்."
    },
    "no_audio": {
        "hi": "कृपया पहले अपनी आवाज़ रिकॉर्ड करें।",
        "en": "Please record your voice first.",
        "mr": "कृपया आधी आवाज रेकॉर्ड करा.",
        "ta": "தயவுசெய்து முதலில் பேசவும்."
    },
    "unsupported_lang": {
        "hi": "यह भाषा अभी उपलब्ध नहीं है, कृपया हिंदी या अंग्रेजी चुनें।",
        "en": "This language is not supported yet, please choose Hindi or English.",
        "mr": "ही भाषा उपलब्ध नाही, कृपया हिंदी किंवा इंग्रजी निवडा.",
        "ta": "இந்த மொழி கிடைக்கவில்லை, இந்தி அல்லது ஆங்கிலம் தேர்ந்தெடுக்கவும்."
    }
}


def get_friendly_error(error_key: str, lang_code: str = "hi") -> str:
    """Returns a friendly error string with bilingual English fallback."""
    err_dict = FRIENDLY_ERRORS.get(error_key, FRIENDLY_ERRORS["unclear_audio"])
    local_msg = err_dict.get(lang_code, err_dict.get("hi"))
    en_msg = err_dict.get("en")
    return f"{local_msg} ({en_msg})"


def _convert_audio_to_wav(audio_bytes: bytes, filename: str) -> bytes:
    """Convert any audio format (MP3, OGG, M4A, WEBM, etc.) to 16-bit PCM WAV.

    Uses pydub + ffmpeg for non-WAV formats. Returns original bytes if already WAV.
    """
    # If already a valid WAV, return as-is
    if audio_bytes[:4] == b'RIFF' and b'WAVE' in audio_bytes[:12]:
        logger.info(f"Audio is already WAV format, no conversion needed ({len(audio_bytes)} bytes)")
        return audio_bytes

    # Detect format from magic bytes / filename extension
    ext = os.path.splitext(filename)[1].lower().lstrip('.')
    if not ext or ext == 'wav':
        # Try to guess from magic bytes
        if audio_bytes[:3] == b'ID3' or audio_bytes[:2] == b'\xff\xfb' or audio_bytes[:2] == b'\xff\xf3':
            ext = 'mp3'
        elif audio_bytes[:4] == b'OggS':
            ext = 'ogg'
        elif audio_bytes[:4] == b'fLaC':
            ext = 'flac'
        elif audio_bytes[4:8] == b'ftyp':
            ext = 'm4a'
        else:
            ext = 'mp3'  # Default guess for unknown formats

    logger.info(f"Converting {ext.upper()} audio ({len(audio_bytes)} bytes) to WAV via pydub+ffmpeg...")

    try:
        from pydub import AudioSegment
        audio_segment = AudioSegment.from_file(io.BytesIO(audio_bytes), format=ext)

        # Convert to mono, 16-bit, 16kHz WAV (optimal for speech recognition)
        audio_segment = audio_segment.set_channels(1).set_sample_width(2).set_frame_rate(16000)

        wav_buffer = io.BytesIO()
        audio_segment.export(wav_buffer, format="wav")
        wav_bytes = wav_buffer.getvalue()

        logger.info(f"Conversion successful: {ext.upper()} -> WAV ({len(wav_bytes)} bytes, "
                     f"duration={len(audio_segment)}ms)")
        return wav_bytes

    except ImportError:
        logger.error("pydub is not installed. Cannot convert non-WAV audio. "
                      "Install with: python -m pip install pydub")
        raise ValueError(
            f"Cannot process {ext.upper()} audio: pydub library not installed. "
            f"Only WAV files are supported without pydub."
        )
    except Exception as e:
        logger.error(f"Audio conversion failed ({ext.upper()} -> WAV): {type(e).__name__}: {e}")
        # Check if it's an ffmpeg-not-found error
        err_str = str(e).lower()
        if 'ffmpeg' in err_str or 'ffprobe' in err_str or 'filenotfounderror' in err_str:
            raise ValueError(
                f"Cannot convert {ext.upper()} to WAV: ffmpeg is not installed or not on PATH. "
                f"Install ffmpeg: winget install Gyan.FFmpeg"
            )
        raise ValueError(f"Audio format conversion failed: {e}")


def transcribe_audio(audio_bytes: bytes, filename: str = "audio.wav", lang_code: str = "hi") -> dict:
    """Transcribe audio bytes using SpeechRecognition (Google Speech Recognition engine).

    Properly handles MP3, OGG, M4A, WEBM, and other formats by converting to WAV first.
    Returns:
        { "success": bool, "transcript": str, "error": str|None, "friendly_error": str|None }
    """
    if not audio_bytes or len(audio_bytes) < 100:
        return {
            "success": False,
            "transcript": "",
            "error": "Audio file is empty or too short",
            "friendly_error": get_friendly_error("no_audio", lang_code)
        }

    logger.info(f"transcribe_audio called: filename={filename}, size={len(audio_bytes)} bytes, "
                f"lang={lang_code}, first_4_bytes={audio_bytes[:4]}")

    locale = LANG_LOCALE_MAP.get(lang_code.lower().strip(), "hi-IN")

    # Step 1: Convert to WAV if needed (handles MP3, OGG, M4A, etc.)
    try:
        wav_bytes = _convert_audio_to_wav(audio_bytes, filename)
    except ValueError as conv_err:
        logger.error(f"Audio conversion error: {conv_err}")
        return {
            "success": False,
            "transcript": "",
            "error": str(conv_err),
            "friendly_error": get_friendly_error("unclear_audio", lang_code)
        }

    # Step 2: Transcribe the WAV audio
    recognizer = sr.Recognizer()
    recognizer.energy_threshold = 300
    recognizer.dynamic_energy_threshold = True

    try:
        with io.BytesIO(wav_bytes) as audio_file:
            with sr.AudioFile(audio_file) as source:
                audio_data = recognizer.record(source)

                logger.info(f"Audio loaded for recognition: "
                            f"sample_rate={audio_data.sample_rate}, "
                            f"sample_width={audio_data.sample_width}, "
                            f"data_length={len(audio_data.frame_data)} bytes")

                transcript = recognizer.recognize_google(audio_data, language=locale)
                logger.info(f"Speech successfully transcribed [{locale}]: {transcript}")
                return {
                    "success": True,
                    "transcript": transcript,
                    "language": lang_code,
                    "error": None
                }

    except sr.UnknownValueError as uve:
        # Log the ACTUAL error details instead of hiding them
        logger.error(f"Google Speech Recognition UnknownValueError for {filename} "
                     f"(locale={locale}, size={len(wav_bytes)} bytes): "
                     f"The API returned no transcription results. "
                     f"This may mean: (1) audio contains no recognizable speech, "
                     f"(2) wrong language code, or (3) audio is too short/noisy. "
                     f"Exception details: {type(uve).__name__}: {uve}")
        return {
            "success": False,
            "transcript": "",
            "error": (f"Speech was unintelligible (Google STT returned no results for "
                      f"locale={locale}). Check server logs for details."),
            "friendly_error": get_friendly_error("unclear_audio", lang_code)
        }
    except sr.RequestError as req_err:
        logger.error(f"Google Speech Recognition RequestError: {type(req_err).__name__}: {req_err}")
        return {
            "success": False,
            "transcript": "",
            "error": f"Speech service unavailable: {req_err}",
            "friendly_error": get_friendly_error("unclear_audio", lang_code)
        }
    except Exception as e:
        # NEVER silently swallow exceptions — log the full details
        logger.error(f"Audio transcription unexpected error: {type(e).__name__}: {e}", exc_info=True)
        return {
            "success": False,
            "transcript": "",
            "error": f"Transcription failed: {type(e).__name__}: {e}",
            "friendly_error": get_friendly_error("unclear_audio", lang_code)
        }
