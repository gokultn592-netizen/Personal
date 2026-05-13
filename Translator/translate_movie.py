"""
Universal Movie Translator - ONE SCRIPT FOR ALL MOVIES
========================================================
Load config from JSON file. No code editing needed.

Usage:
python translate_movie.py --config "movie_configs/puss_in_boots.json" --input "video.mp4" --output "tamil.mp4"
"""

import argparse
import json
import os
import sys
import asyncio
import subprocess
import warnings
import time
import re

warnings.filterwarnings("ignore")

START_TIME = time.time()


def elapsed():
    mins = (time.time() - START_TIME) / 60
    print(f"\n⏱ Total elapsed: {mins:.1f} min")


def parse_args():
    parser = argparse.ArgumentParser(description="Universal Movie Translator")
    parser.add_argument("--config", required=True, help="Path to JSON config file")
    parser.add_argument("--input", required=True, help="Input video (.mp4 or .mkv)")
    parser.add_argument("--output", required=True, help="Output translated video (.mp4)")
    parser.add_argument("--whisper_model", default="medium", help="tiny/base/small/medium/large")
    parser.add_argument("--voice", default="ta-IN-ValluvarNeural", help="Tamil Edge-TTS voice")
    return parser.parse_args()


def load_config(config_path):
    """Load movie configuration from JSON."""
    with open(config_path, 'r', encoding='utf-8') as f:
        return json.load(f)


def get_duration(path):
    result = subprocess.run(
        ["ffprobe", "-v", "error", "-show_entries", "format=duration",
         "-of", "default=noprint_wrappers=1:nokey=1", path],
        capture_output=True, text=True
    )
    return float(result.stdout.strip())


def extract_audio(video_path, audio_path="temp_audio.wav"):
    print("\n[1/6] Extracting audio from video...")
    cmd = ["ffmpeg", "-y", "-i", video_path, "-ac", "2", "-ar", "44100", "-vn", audio_path]
    result = subprocess.run(cmd, capture_output=True, text=True)
    if result.returncode != 0:
        print("\nFFmpeg Error:", result.stderr)
        sys.exit(1)
    print(f"    Audio extracted → {audio_path}")
    elapsed()
    return audio_path


def separate_audio(audio_path):
    print("\n[2/6] Separating vocals/background (Demucs)...")
    cmd = [sys.executable, "-m", "demucs", "--two-stems=vocals", "--mp3", "-o", "temp_demucs", audio_path]
    result = subprocess.run(cmd, capture_output=True, text=True)
    if result.returncode != 0:
        print("\nDemucs Error:", result.stderr)
        sys.exit(1)
    base_name = os.path.splitext(os.path.basename(audio_path))[0]
    vocals_path = f"temp_demucs/htdemucs/{base_name}/vocals.mp3"
    no_vocals_path = f"temp_demucs/htdemucs/{base_name}/no_vocals.mp3"
    print(f"    Vocals     → {vocals_path}")
    print(f"    Background → {no_vocals_path}")
    elapsed()
    return vocals_path, no_vocals_path


def transcribe_audio(vocals_path, model_size="medium"):
    print(f"\n[3/6] Transcribing audio (Whisper {model_size})...")
    import whisper
    import torch
    device = "cuda" if torch.cuda.is_available() else "cpu"
    print(f"    Device → {device}")
    model = whisper.load_model(model_size).to(device)
    result = model.transcribe(vocals_path, language="en", task="transcribe")
    print(f"    Transcription done → {len(result['segments'])} segments")
    elapsed()
    return result["text"], result["segments"]


def split_long_segments(segments, max_chars=100):
    """Split segments with very long text into smaller chunks."""
    new_segments = []
    
    for seg in segments:
        text = seg['text'].strip()
        duration = seg['end'] - seg['start']
        
        if len(text) > max_chars and duration > 3.0:
            parts = re.split(r'(?<=[.!?])\s+', text)
            
            if len(parts) > 1:
                mid = len(parts) // 2
                part1_text = ' '.join(parts[:mid]).strip()
                part2_text = ' '.join(parts[mid:]).strip()
                
                mid_time = seg['start'] + (duration / 2)
                
                new_segments.append({
                    'start': seg['start'],
                    'end': mid_time,
                    'text': part1_text
                })
                new_segments.append({
                    'start': mid_time,
                    'end': seg['end'],
                    'text': part2_text
                })
                continue
        
        new_segments.append(seg)
    
    print(f"    Split {len(segments)} segments into {len(new_segments)} (long ones divided)")
    return new_segments


def protect_english_words(text, preserve_list):
    """Replace English words with placeholders before translation."""
    protected = {}
    placeholder_count = 0
    
    for word in sorted(preserve_list, key=len, reverse=True):
        pattern = r'\b' + re.escape(word) + r'\b'
        
        def replace_match(match):
            nonlocal placeholder_count
            placeholder = f"__ENG{placeholder_count}__"
            protected[placeholder] = match.group(0)
            placeholder_count += 1
            return placeholder
        
        text, _ = re.subn(pattern, replace_match, text, flags=re.IGNORECASE)
    
    return text, protected


def restore_english_words(text, protected):
    """Restore original English words from placeholders."""
    for placeholder, original in protected.items():
        text = text.replace(placeholder, original)
    return text


def translate_to_tamil_preserve(text, preserve_list):
    """Translate to Tamil but preserve iconic English words."""
    from deep_translator import GoogleTranslator
    
    protected_text, protected_map = protect_english_words(text, preserve_list)
    
    translator = GoogleTranslator(source='en', target='ta')
    try:
        translated = translator.translate(protected_text)
    except Exception as e:
        print(f"    ⚠ Translation failed: {e}")
        return text
    
    final_text = restore_english_words(translated, protected_map)
    final_text = re.sub(r'\s+', ' ', final_text).strip()
    
    return final_text


def detect_character(text, character_keywords):
    """Detect which character is speaking based on keywords."""
    text_lower = text.lower()
    for char_name, keywords in character_keywords.items():
        if char_name == "default":
            continue
        if any(kw in text_lower for kw in keywords):
            return char_name
    return "default"


def apply_voice_effect(input_path, output_path, effect_config):
    """Apply voice effect based on config."""
    pitch = effect_config.get("pitch", 1.0)
    reverb = effect_config.get("reverb", False)
    
    filters = []
    
    if pitch != 1.0:
        filters.append(f"asetrate=44100*{pitch},atempo=1/{pitch}")
    
    if reverb:
        filters.append("aecho=0.5:0.3:40:0.2")
    
    filters.append("highpass=f=60,lowpass=f=8000")
    
    filter_str = ",".join(filters)
    
    cmd = [
        "ffmpeg", "-y", "-i", input_path,
        "-af", filter_str,
        "-ar", "44100", "-ac", "2",
        output_path
    ]
    subprocess.run(cmd, capture_output=True, text=True)
    return output_path


async def generate_segment_tts(text, output_path, voice="ta-IN-ValluvarNeural"):
    import edge_tts
    try:
        communicate = edge_tts.Communicate(text, voice)
        await communicate.save(output_path)
        return True
    except Exception as e:
        print(f"    ⚠ TTS failed: {e}")
        return False


async def process_all_segments(segments, voice, config):
    """Process all segments with config settings."""
    print("\n[4-5/6] Translating & Generating TTS per segment...")
    
    preserve_list = config.get("preserve_english", [])
    character_keywords = config.get("character_keywords", {})
    voice_effects = config.get("voice_effects", {})
    
    processed = []
    total = len(segments)
    
    for i, seg in enumerate(segments):
        start = seg['start']
        end = seg['end']
        orig_text = seg['text'].strip()
        
        character = detect_character(orig_text, character_keywords)
        
        print(f"\n    Segment {i+1}/{total} [{start:.1f}s - {end:.1f}s] [{character.upper()}]")
        print(f"    EN: {orig_text}")
        
        tamil_text = translate_to_tamil_preserve(orig_text, preserve_list)
        print(f"    TA: {tamil_text}")
        
        raw_audio = f"temp_raw_{i:04d}.mp3"
        success = await generate_segment_tts(tamil_text, raw_audio, voice)
        
        if success and os.path.exists(raw_audio):
            final_audio = f"temp_seg_{i:04d}.mp3"
            
            effect_config = voice_effects.get(character, voice_effects.get("default", {"pitch": 1.0, "reverb": False}))
            apply_voice_effect(raw_audio, final_audio, effect_config)
            
            if effect_config.get("pitch", 1.0) != 1.0 or effect_config.get("reverb", False):
                print(f"    ✓ {character.upper()} effect applied")
            else:
                print(f"    ✓ Default (no effect)")
            
            if os.path.exists(raw_audio):
                os.remove(raw_audio)
            
            tts_duration = get_duration(final_audio)
            orig_duration = end - start
            
            processed.append({
                'index': i,
                'start': start,
                'end': end,
                'orig_duration': orig_duration,
                'tts_duration': tts_duration,
                'text': tamil_text,
                'audio': final_audio,
                'character': character
            })
            
            print(f"    ✓ Final duration: {tts_duration:.2f}s (target: {orig_duration:.2f}s)")
        else:
            print(f"    ✗ Failed to generate TTS for segment {i+1}")
        
        await asyncio.sleep(0.15)
    
    print(f"\n    Successfully processed {len(processed)}/{total} segments")
    elapsed()
    return processed


def build_synced_track(segments, total_duration, output_path="tamil_synced.wav"):
    """Build synced audio track with SMART speed limits."""
    print("\n    Building synced audio track...")
    
    if not segments:
        print("    ✗ No segments to process")
        return None
    
    processed_files = []
    
    for i, seg in enumerate(segments):
        ratio = seg['tts_duration'] / seg['orig_duration']
        
        # SMART SPEED LIMITS
        if ratio > 1.5:
            print(f"    ⚠ Segment {i+1}: TTS too long ({ratio:.2f}x). Trimming with fade.")
            target_ratio = 1.0
            trim_with_fade = True
        elif ratio > 1.2:
            print(f"    ℹ Segment {i+1}: TTS long ({ratio:.2f}x). Limiting to 1.2x stretch.")
            target_ratio = 1.2
            trim_with_fade = False
        elif ratio < 0.6:
            print(f"    ℹ Segment {i+1}: TTS short ({ratio:.2f}x). Min stretch 0.6x.")
            target_ratio = 0.6
            trim_with_fade = False
        else:
            target_ratio = ratio
            trim_with_fade = False
        
        # Build atempo chain
        tempos = []
        temp_ratio = target_ratio
        while temp_ratio > 2.0:
            tempos.append("atempo=2.0")
            temp_ratio /= 2.0
        while temp_ratio < 0.5:
            tempos.append("atempo=0.5")
            temp_ratio /= 0.5
        tempos.append(f"atempo={temp_ratio:.4f}")
        atempo_str = ",".join(tempos)
        
        # Apply speed adjustment
        speed_file = f"temp_speed_{i:04d}.mp3"
        speed_cmd = [
            "ffmpeg", "-y", "-i", seg['audio'],
            "-filter:a", atempo_str,
            "-ar", "44100", "-ac", "2",
            speed_file
        ]
        subprocess.run(speed_cmd, capture_output=True, text=True)
        
        # Process based on trim needs
        if trim_with_fade:
            final_file = f"temp_final_{i:04d}.mp3"
            fade_start = max(0, seg['orig_duration'] - 0.5)
            fade_cmd = [
                "ffmpeg", "-y", "-i", speed_file,
                "-af", f"afade=t=out:st={fade_start}:d=0.5",
                "-t", str(seg['orig_duration']),
                "-ar", "44100", "-ac", "2",
                final_file
            ]
            subprocess.run(fade_cmd, capture_output=True, text=True)
        else:
            final_file = f"temp_final_{i:04d}.mp3"
            pad_cmd = [
                "ffmpeg", "-y", "-i", speed_file,
                "-af", f"apad=pad_dur={seg['orig_duration'] + 1},atrim=duration={seg['orig_duration']}",
                "-ar", "44100", "-ac", "2",
                final_file
            ]
            subprocess.run(pad_cmd, capture_output=True, text=True)
        
        actual_dur = get_duration(final_file)
        print(f"    Segment {i+1} [{seg['character']}]: target={seg['orig_duration']:.2f}s, actual={actual_dur:.2f}s, ratio={ratio:.2f}x, applied={target_ratio:.2f}x")
        
        processed_files.append({
            'file': final_file,
            'start': seg['start'],
            'duration': seg['orig_duration']
        })
        
        if os.path.exists(speed_file):
            os.remove(speed_file)
    
    # Build silent gaps and concatenate
    full_track_segments = []
    
    for i, pf in enumerate(processed_files):
        if i == 0:
            silence_dur = pf['start']
        else:
            prev_end = processed_files[i-1]['start'] + processed_files[i-1]['duration']
            silence_dur = pf['start'] - prev_end
        
        if silence_dur > 0.01:
            silence_file = f"temp_silence_{i:04d}.mp3"
            subprocess.run([
                "ffmpeg", "-y", "-f", "lavfi", "-i", 
                f"anullsrc=r=44100:cl=stereo", 
                "-t", str(silence_dur),
                "-acodec", "libmp3lame", "-q:a", "2",
                silence_file
            ], capture_output=True)
            full_track_segments.append(silence_file)
        
        full_track_segments.append(pf['file'])
    
    list_file = "temp_concat_list.txt"
    with open(list_file, "w", encoding="utf-8") as f:
        for seg_file in full_track_segments:
            f.write(f"file '{os.path.abspath(seg_file)}'\n")
    
    concat_cmd = [
        "ffmpeg", "-y", "-f", "concat", "-safe", "0",
        "-i", list_file,
        "-c", "copy",
        output_path
    ]
    result = subprocess.run(concat_cmd, capture_output=True, text=True)
    
    os.remove(list_file)
    for f in full_track_segments:
        if os.path.exists(f) and f != output_path:
            os.remove(f)
    
    if result.returncode != 0:
        print(f"    ✗ Concat error: {result.stderr[:500]}")
        return None
    
    out_dur = get_duration(output_path)
    print(f"    ✓ Synced track built: {out_dur:.1f}s → {output_path}")
    return output_path


def mix_and_merge(video_path, tamil_voice_path, background_path, output_path):
    print("\n[6/6] Mixing Tamil voice with background & merging...")
    
    tamil_dur = get_duration(tamil_voice_path)
    print(f"    Tamil voice duration: {tamil_dur:.1f}s")
    
    mixed_audio = "temp_mixed.wav"
    mix_cmd = [
        "ffmpeg", "-y",
        "-i", tamil_voice_path,
        "-i", background_path,
        "-filter_complex", "[0:a][1:a]amix=inputs=2:duration=longest:weights=2.5 1[aout]",
        "-map", "[aout]",
        "-ar", "44100", "-ac", "2",
        mixed_audio
    ]
    result = subprocess.run(mix_cmd, capture_output=True, text=True)
    if result.returncode != 0:
        print("\nFFmpeg Mix Error:", result.stderr)
        mixed_audio = tamil_voice_path
        print("    ⚠ Fallback: using Tamil voice only")
    
    merge_cmd = [
        "ffmpeg", "-y",
        "-i", video_path,
        "-i", mixed_audio,
        "-c:v", "copy",
        "-map", "0:v:0",
        "-map", "1:a:0",
        "-shortest",
        output_path
    ]
    result = subprocess.run(merge_cmd, capture_output=True, text=True)
    if result.returncode != 0:
        print("\nFFmpeg Merge Error:", result.stderr)
        sys.exit(1)
    
    out_dur = get_duration(output_path)
    print(f"    ✓ Final video saved: {out_dur:.1f}s → {output_path}")
    elapsed()


def cleanup(processed_segments):
    print("\nCleaning temporary files...")
    
    files_to_delete = ["temp_audio.wav", "temp_mixed.wav", "tamil_synced.wav"]
    for f in files_to_delete:
        if os.path.exists(f):
            os.remove(f)
            print(f"    Deleted → {f}")
    
    for seg in processed_segments:
        if os.path.exists(seg['audio']):
            os.remove(seg['audio'])
    
    if os.path.exists("temp_demucs"):
        import shutil
        shutil.rmtree("temp_demucs")
        print("    Deleted → temp_demucs/")


def main():
    args = parse_args()
    
    config = load_config(args.config)
    movie_name = config.get("movie_name", "Unknown Movie")
    
    if not os.path.exists(args.input):
        print(f"\nError: File not found → {args.input}")
        sys.exit(1)
    
    ext = os.path.splitext(args.input)[1].lower()
    if ext not in [".mp4", ".mkv"]:
        print("\nOnly MP4/MKV supported")
        sys.exit(1)
    
    print("=" * 60)
    print(f" {movie_name} - TAMIL DUB ")
    print("=" * 60)
    print(f"Config        : {args.config}")
    print(f"Input         : {args.input}")
    print(f"Output        : {args.output}")
    print(f"Whisper Model : {args.whisper_model}")
    print(f"TTS Voice     : {args.voice}")
    print("=" * 60)
    
    # Pipeline
    audio_path = extract_audio(args.input)
    vocals_path, bg_path = separate_audio(audio_path)
    english_text, segments = transcribe_audio(vocals_path, args.whisper_model)
    
    # Split long segments
    print(f"\n    Checking for long segments...")
    segments = split_long_segments(segments, max_chars=100)
    
    video_duration = get_duration(args.input)
    print(f"\n    Video duration: {video_duration:.1f}s")
    
    # Process with config
    processed_segments = asyncio.run(process_all_segments(segments, args.voice, config))
    
    if not processed_segments:
        print("\n✗ No segments processed successfully")
        sys.exit(1)
    
    # Build synced audio with smart speed limits
    synced_audio = build_synced_track(processed_segments, video_duration)
    
    if synced_audio and os.path.exists(synced_audio):
        mix_and_merge(args.input, synced_audio, bg_path, args.output)
        cleanup(processed_segments)
    else:
        print("\n✗ Failed to build synced audio")
        sys.exit(1)
    
    total_time = (time.time() - START_TIME) / 60
    print("\n" + "=" * 60)
    print(" DONE! ")
    print("=" * 60)
    print(f"Output Video : {args.output}")
    print(f"Total Time   : {total_time:.1f} min")
    print("=" * 60)


if __name__ == "__main__":
    main()