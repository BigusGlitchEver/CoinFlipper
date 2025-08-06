const fs = require('fs');
const path = require('path');
const { execSync } = require('child_process');

// --- Configuration ---
const GAME_NAME = 'Anafuda';
// IMPORTANT: Set this to your local LÖVE installation directory
const LOVE_DIR_PATH = 'C:\\Program Files\\LOVE';

const BUILD_DIR = path.join(__dirname, 'build');
const DIST_DIR = path.join(__dirname, 'dist');
const LOVE_EXE_PATH = path.join(LOVE_DIR_PATH, 'love.exe');
const LOVE_FILE_PATH = path.join(BUILD_DIR, `${GAME_NAME}.love`);
const GAME_EXE_PATH = path.join(DIST_DIR, `${GAME_NAME}.exe`);

// Files and directories to be included in the .love file
const SOURCE_FILES = [
    'main.lua',
    'conf.lua',
    'gamestate.lua',
    'assets',
    'components',
    'data',
    'gamestates',
    'helpers',
    'lib',
    'shaders'
];

// --- Helper Functions ---

function log(message) {
    console.log(`[BUILD] ${message}`);
}

function runCommand(command, options = {}) {
    log(`Executing: ${command}`);
    try {
        execSync(command, { stdio: 'inherit', ...options });
    } catch (error) {
        console.error(`Error executing command: ${command}`);
        process.exit(1);
    }
}

function ensureDirExists(dirPath) {
    if (!fs.existsSync(dirPath)) {
        log(`Creating directory: ${dirPath}`);
        fs.mkdirSync(dirPath, { recursive: true });
    }
}

// --- Build Steps ---

function main() {
    log('Starting build process using local LÖVE installation...');
    ensureDirExists(BUILD_DIR);
    ensureDirExists(DIST_DIR);

    // 1. Verify LÖVE installation path
    log(`Using LÖVE from: ${LOVE_DIR_PATH}`);
    if (!fs.existsSync(LOVE_DIR_PATH) || !fs.existsSync(LOVE_EXE_PATH)) {
        console.error(`Error: LÖVE installation not found at '${LOVE_DIR_PATH}'.`);
        console.error('Please check the LOVE_DIR_PATH variable in this script.');
        process.exit(1);
    }

    // 2. Create .love file
    log(`Creating ${GAME_NAME}.love file...`);
    const tempZipPath = path.join(BUILD_DIR, `${GAME_NAME}.zip`);
    if (fs.existsSync(tempZipPath)) {
        fs.unlinkSync(tempZipPath);
    }
    const sourcePaths = SOURCE_FILES.join(' ');
    const zipCommand = `tar -a -c -f "${tempZipPath}" ${sourcePaths}`;
    runCommand(zipCommand, { cwd: __dirname });

    if (fs.existsSync(LOVE_FILE_PATH)) {
        fs.unlinkSync(LOVE_FILE_PATH);
    }
    fs.renameSync(tempZipPath, LOVE_FILE_PATH);
    log('.love file created.');

    // 3. Create game executable
    log('Creating game executable...');
    const copyCommand = `cmd /c copy /b "${LOVE_EXE_PATH}"+"${LOVE_FILE_PATH}" "${GAME_EXE_PATH}"`;
    runCommand(copyCommand);
    log('Game executable created.');

    // 4. Copy DLLs and license to dist folder
    log('Copying required files to dist folder...');
    const requiredFiles = fs.readdirSync(LOVE_DIR_PATH).filter(file => 
        file.endsWith('.dll') || file === 'license.txt'
    );
    requiredFiles.forEach(file => {
        const src = path.join(LOVE_DIR_PATH, file);
        const dest = path.join(DIST_DIR, file);
        fs.copyFileSync(src, dest);
    });
    log('All files copied.');

    log(`\nBuild successful! Your distributable game is in the '${path.resolve(DIST_DIR)}' folder.`);
}

main();
