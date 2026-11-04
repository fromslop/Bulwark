@echo off
rem Rebuilds every enemy model (assets\enemies\*.glb) from tools\enemy_models.py, then
rem renders them to shots\model_*.png for a look. Pass character slugs to build only those,
rem e.g. build_enemies footman wraith. Edit the paths below if Blender or Godot move.
setlocal
set BLENDER=C:\Program Files\Blender Foundation\Blender 5.1\blender.exe
set GODOT=C:\Users\EV-02\Desktop\Godot_v4.7.2-stable_win64.exe
cd /d "%~dp0.."
"%BLENDER%" --background --python tools\enemy_models.py -- %* | findstr /r /c:"tris" /c:"Error" /c:"Traceback"
if errorlevel 1 exit /b 1
"%GODOT%" --path . -s res://tests/model_shots.gd
echo shots in shots\model_*.png
