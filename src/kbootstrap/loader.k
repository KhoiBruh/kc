module kbootstrap.loader;

import kbootstrap.source.Source;
import kbootstrap.token.Token;
import kbootstrap.containers.ByteBuffer;
import kbootstrap.lexer.lex;

extern fn k_boot_current_directory(data: u8**, dataLength: u64*): bool;
extern fn k_boot_canonical_path(
    path: u8*, pathLength: u64, data: u8**, dataLength: u64*): bool;

struct LoadedPath(data: u8*, length: u64)
struct LoadedPathList(data: LoadedPath*, length: u64, capacity: u64)
struct LoadedModule(path: LoadedPath, data: u8*, length: u64)
struct LoadedModuleList(data: LoadedModule*, length: u64, capacity: u64)
struct SourceMapSegment(
    path: u8*, pathLength: u64, sourceStart: u64, sourceLength: u64)
struct SourceMap(data: SourceMapSegment*, length: u64, capacity: u64)
struct LoadResult(source: Source, sourceMap: SourceMap, ok: bool)
struct ModuleLoader(
    modules: LoadedModuleList,
    visited: LoadedPathList,
    workingDirectory: LoadedPath,
    entryDirectory: ByteBuffer)

fn loadedModuleListNew(): LoadedModuleList {
    return LoadedModuleList(
        k_boot_alloc(2 * sizeof(LoadedModule)) as LoadedModule*, 0, 2);
}

fn loadedModuleListAppend(var list: LoadedModuleList, loadedModule: LoadedModule) {
    if (list.length == list.capacity) {
        val capacity = list.capacity * 2;
        val data = k_boot_alloc(capacity * sizeof(LoadedModule)) as LoadedModule*;
        var index: u64 = 0;
        while (index < list.length) {
            data[index] = list.data[index];
            index = index + 1;
        }
        k_boot_free(list.data as unit*);
        list.data = data;
        list.capacity = capacity;
    }
    list.data[list.length] = loadedModule;
    list.length = list.length + 1;
}

fn loadedPathListNew(): LoadedPathList {
    return LoadedPathList(
        k_boot_alloc(2 * sizeof(LoadedPath)) as LoadedPath*, 0, 2);
}

fn loadedPathListAppend(var list: LoadedPathList, path: LoadedPath) {
    if (list.length == list.capacity) {
        val capacity = list.capacity * 2;
        val data = k_boot_alloc(capacity * sizeof(LoadedPath)) as LoadedPath*;
        var index: u64 = 0;
        while (index < list.length) {
            data[index] = list.data[index];
            index = index + 1;
        }
        k_boot_free(list.data as unit*);
        list.data = data;
        list.capacity = capacity;
    }
    list.data[list.length] = path;
    list.length = list.length + 1;
}

fn sourceMapNew(): SourceMap {
    return SourceMap(
        k_boot_alloc(2 * sizeof(SourceMapSegment)) as SourceMapSegment*, 0, 2);
}

fn sourceMapAppend(var sourceMap: SourceMap, segment: SourceMapSegment) {
    if (sourceMap.length == sourceMap.capacity) {
        val capacity = sourceMap.capacity * 2;
        val data = k_boot_alloc(capacity * sizeof(SourceMapSegment)) as SourceMapSegment*;
        var index: u64 = 0;
        while (index < sourceMap.length) {
            data[index] = sourceMap.data[index];
            index = index + 1;
        }
        k_boot_free(sourceMap.data as unit*);
        sourceMap.data = data;
        sourceMap.capacity = capacity;
    }
    sourceMap.data[sourceMap.length] = segment;
    sourceMap.length = sourceMap.length + 1;
}

fn sourceMapFree(sourceMap: SourceMap) {
    var index: u64 = 0;
    while (index < sourceMap.length) {
        k_boot_free(sourceMap.data[index].path as unit*);
        index = index + 1;
    }
    k_boot_free(sourceMap.data as unit*);
}

fn loaderBytesEqual(a: u8*, aLength: u64, b: u8*, bLength: u64): bool {
    if (aLength != bLength) { return false; }
    var index: u64 = 0;
    while (index < aLength) {
        if (a[index] != b[index]) { return false; }
        index = index + 1;
    }
    return true;
}

fn loaderWasVisited(loader: ModuleLoader, path: LoadedPath): bool {
    var index: u64 = 0;
    while (index < loader.visited.length) {
        val other = loader.visited.data[index];
        if (loaderBytesEqual(path.data, path.length, other.data, other.length)) {
            return true;
        }
        index = index + 1;
    }
    return false;
}

fn loaderAppend(var buffer: ByteBuffer, data: u8*, length: u64) {
    var index: u64 = 0;
    while (index < length) {
        byteBufferAppend(buffer, data[index]);
        index = index + 1;
    }
}

fn loaderAppendNumber(var buffer: ByteBuffer, value: u64) {
    var digits = byteBufferNew();
    var current = value;
    if (current == 0) { byteBufferAppend(digits, 48); }
    while (current > 0) {
        byteBufferAppend(digits, 48 + (current % 10) as u8);
        current = current / 10;
    }
    var index = digits.length;
    while (index > 0) {
        index = index - 1;
        byteBufferAppend(buffer, digits.data[index]);
    }
    byteBufferFree(digits);
}

fn loaderReport(
    path: LoadedPath, source: Source, offset: u64, category: u32) {
    var line: u64 = 1;
    var column: u64 = 1;
    var index: u64 = 0;
    while (index < offset) {
        if (source.data[index] == 10) {
            line = line + 1;
            column = 1;
        } else {
            column = column + 1;
        }
        index = index + 1;
    }
    var message = byteBufferNew();
    loaderAppend(message, path.data, path.length);
    byteBufferAppend(message, 58); loaderAppendNumber(message, line);
    byteBufferAppend(message, 58); loaderAppendNumber(message, column);
    byteBufferAppend(message, 58); byteBufferAppend(message, 32);
    byteBufferAppend(message, 101); byteBufferAppend(message, 114);
    byteBufferAppend(message, 114); byteBufferAppend(message, 111);
    byteBufferAppend(message, 114); byteBufferAppend(message, 58);
    byteBufferAppend(message, 32);
    if (category == 1) {
        byteBufferAppend(message, 99); byteBufferAppend(message, 97);
        byteBufferAppend(message, 110); byteBufferAppend(message, 110);
        byteBufferAppend(message, 111); byteBufferAppend(message, 116);
        byteBufferAppend(message, 32); byteBufferAppend(message, 114);
        byteBufferAppend(message, 101); byteBufferAppend(message, 115);
        byteBufferAppend(message, 111); byteBufferAppend(message, 108);
        byteBufferAppend(message, 118); byteBufferAppend(message, 101);
        byteBufferAppend(message, 32); byteBufferAppend(message, 105);
        byteBufferAppend(message, 109); byteBufferAppend(message, 112);
        byteBufferAppend(message, 111); byteBufferAppend(message, 114);
        byteBufferAppend(message, 116);
    } else {
        if (category == 2) {
            byteBufferAppend(message, 109); byteBufferAppend(message, 111);
            byteBufferAppend(message, 100); byteBufferAppend(message, 117);
            byteBufferAppend(message, 108); byteBufferAppend(message, 101);
            byteBufferAppend(message, 32); byteBufferAppend(message, 105);
            byteBufferAppend(message, 109); byteBufferAppend(message, 112);
            byteBufferAppend(message, 111); byteBufferAppend(message, 114);
            byteBufferAppend(message, 116); byteBufferAppend(message, 32);
            byteBufferAppend(message, 100); byteBufferAppend(message, 101);
            byteBufferAppend(message, 112); byteBufferAppend(message, 116);
            byteBufferAppend(message, 104); byteBufferAppend(message, 32);
            byteBufferAppend(message, 101); byteBufferAppend(message, 120);
            byteBufferAppend(message, 99); byteBufferAppend(message, 101);
            byteBufferAppend(message, 101); byteBufferAppend(message, 100);
            byteBufferAppend(message, 101); byteBufferAppend(message, 100);
        } else {
            byteBufferAppend(message, 105); byteBufferAppend(message, 110);
            byteBufferAppend(message, 118); byteBufferAppend(message, 97);
            byteBufferAppend(message, 108); byteBufferAppend(message, 105);
            byteBufferAppend(message, 100); byteBufferAppend(message, 32);
            byteBufferAppend(message, 115); byteBufferAppend(message, 111);
            byteBufferAppend(message, 117); byteBufferAppend(message, 114);
            byteBufferAppend(message, 99); byteBufferAppend(message, 101);
        }
    }
    byteBufferAppend(message, 10);
    k_boot_stderr(message.data, message.length);
    byteBufferFree(message);
}

fn loaderDirectory(path: u8*, length: u64): ByteBuffer {
    var cursor = length;
    var end: u64 = 0;
    var searching = true;
    while (cursor > 0) {
        if (searching) {
            cursor = cursor - 1;
            val value = path[cursor];
            if (value == 47) {
                end = cursor;
                searching = false;
            } else {
                if (value == 92) {
                    end = cursor;
                    searching = false;
                }
            }
        } else {
            cursor = 0;
        }
    }
    var result = byteBufferNew();
    loaderAppend(result, path, end);
    return result;
}

fn loaderCandidate(root: u8*, rootLength: u64, relative: ByteBuffer): ByteBuffer {
    var result = byteBufferNew();
    loaderAppend(result, root, rootLength);
    if (rootLength > 0) { byteBufferAppend(result, 47); }
    loaderAppend(result, relative.data, relative.length);
    return result;
}

fn loaderRelative(
    source: Source, tokens: TokenList, first: u64, partCount: u64,
    wildcard: bool): ByteBuffer {
    var result = byteBufferNew();
    var count = partCount;
    if (wildcard == false) { count = count - 1; }
    var index: u64 = 0;
    while (index < count) {
        if (index > 0) { byteBufferAppend(result, 47); }
        val token = tokens.data[first + index * 2];
        var offset = token.start;
        while (offset < token.end) {
            byteBufferAppend(result, source.data[offset]);
            offset = offset + 1;
        }
        index = index + 1;
    }
    if (wildcard) {
        byteBufferAppend(result, 47);
        byteBufferAppend(result, 109); byteBufferAppend(result, 111);
        byteBufferAppend(result, 100); byteBufferAppend(result, 46);
        byteBufferAppend(result, 107);
    } else {
        byteBufferAppend(result, 46); byteBufferAppend(result, 107);
    }
    return result;
}

fn loaderReadCandidate(
    candidate: ByteBuffer, var data: u8*, var length: u64): bool {
    return k_boot_read_file(candidate.data, candidate.length, &data, &length);
}

fn loaderResolveImport(
    var loader: ModuleLoader, currentPath: LoadedPath, source: Source,
    tokens: TokenList, first: u64, partCount: u64, wildcard: bool,
    start: u64, end: u64, depth: u64): bool {
    if (depth > 64) {
        loaderReport(currentPath, source, start, 2);
        return false;
    }
    if (wildcard == false) {
        if (partCount < 2) {
            loaderReport(currentPath, source, start, 1);
            return false;
        }
    }
    val relative = loaderRelative(source, tokens, first, partCount, wildcard);
    val currentDirectory = loaderDirectory(currentPath.data, currentPath.length);
    var rootIndex: u64 = 0;
    while (rootIndex < 3) {
        var candidate = byteBufferNew();
        if (rootIndex == 0) {
            candidate = loaderCandidate(
                loader.workingDirectory.data, loader.workingDirectory.length,
                relative);
        } else {
            if (rootIndex == 1) {
                candidate = loaderCandidate(
                    loader.entryDirectory.data, loader.entryDirectory.length,
                    relative);
            } else {
                candidate = loaderCandidate(
                    currentDirectory.data, currentDirectory.length, relative);
            }
        }
        val placeholder = k_boot_alloc(1);
        var data = placeholder as u8*;
        var length: u64 = 0;
        if (loaderReadCandidate(candidate, data, length)) {
            k_boot_free(placeholder);
            val loaded = loaderLoadModule(
                loader, candidate.data, candidate.length, depth,
                data, length, true);
            byteBufferFree(candidate);
            byteBufferFree(currentDirectory);
            byteBufferFree(relative);
            return loaded;
        }
        k_boot_free(placeholder);
        byteBufferFree(candidate);
        rootIndex = rootIndex + 1;
    }
    byteBufferFree(currentDirectory);
    byteBufferFree(relative);
    loaderReport(currentPath, source, start, 1);
    return false;
}

fn loaderScanImports(
    var loader: ModuleLoader, path: LoadedPath, source: Source,
    depth: u64): bool {
    val lexed = lex(source);
    if (lexed.ok == false) {
        loaderReport(path, source, lexed.errorStart, 0);
        tokenListFree(lexed.tokens);
        return false;
    }
    val tokens = lexed.tokens;
    var current: u64 = 0;
    if (tokens.data[current].kind == 25) {
        while (tokens.data[current].kind != 58) {
            if (tokens.data[current].kind == 0) {
                tokenListFree(tokens);
                return false;
            }
            current = current + 1;
        }
        current = current + 1;
    }
    while (tokens.data[current].kind == 26) {
        val start = tokens.data[current].start;
        current = current + 1;
        val first = current;
        var partCount: u64 = 0;
        var wildcard = false;
        var scanning = true;
        while (scanning) {
            if (tokens.data[current].kind != 1) {
                scanning = false;
            } else {
                partCount = partCount + 1;
                current = current + 1;
                if (tokens.data[current].kind == 59) {
                    current = current + 1;
                    if (tokens.data[current].kind == 62) {
                        wildcard = true;
                        current = current + 1;
                        scanning = false;
                    }
                } else {
                    scanning = false;
                }
            }
        }
        val end = tokens.data[current].end;
        if (tokens.data[current].kind != 58) {
            tokenListFree(tokens);
            return false;
        }
        current = current + 1;
        if (loaderResolveImport(
                loader, path, source, tokens, first, partCount, wildcard,
                start, end, depth + 1) == false) {
            tokenListFree(tokens);
            return false;
        }
    }
    tokenListFree(tokens);
    return true;
}

fn loaderLoadModule(
    var loader: ModuleLoader, path: u8*, pathLength: u64, depth: u64,
    suppliedData: u8*, suppliedLength: u64, hasSuppliedData: bool): bool {
    if (depth > 64) {
        if (hasSuppliedData) { k_boot_free(suppliedData as unit*); }
        return false;
    }
    val canonicalPlaceholder = k_boot_alloc(1);
    var canonicalData = canonicalPlaceholder as u8*;
    var canonicalLength: u64 = 0;
    if (k_boot_canonical_path(
            path, pathLength, &canonicalData, &canonicalLength) == false) {
        k_boot_free(canonicalData as unit*);
        if (hasSuppliedData) { k_boot_free(suppliedData as unit*); }
        return false;
    }
    k_boot_free(canonicalPlaceholder);
    val canonical = LoadedPath(canonicalData, canonicalLength);
    if (loaderWasVisited(loader, canonical)) {
        k_boot_free(canonical.data as unit*);
        if (hasSuppliedData) { k_boot_free(suppliedData as unit*); }
        return true;
    }
    var visited = loader.visited;
    loadedPathListAppend(visited, canonical);
    loader.visited = visited;
    var data = suppliedData;
    var length = suppliedLength;
    if (hasSuppliedData == false) {
        val sourcePlaceholder = k_boot_alloc(1);
        data = sourcePlaceholder as u8*;
        length = 0;
        if (k_boot_read_file(path, pathLength, &data, &length) == false) {
            k_boot_free(sourcePlaceholder);
            return false;
        }
        k_boot_free(sourcePlaceholder);
    }
    val source = Source(data, length);
    if (loaderScanImports(loader, canonical, source, depth) == false) {
        k_boot_free(data as unit*);
        return false;
    }
    var modules = loader.modules;
    loadedModuleListAppend(modules, LoadedModule(canonical, data, length));
    loader.modules = modules;
    return true;
}

fn loadModules(entryPath: u8*, entryPathLength: u64): LoadResult {
    val workingPlaceholder = k_boot_alloc(1);
    var workingData = workingPlaceholder as u8*;
    var workingLength: u64 = 0;
    if (k_boot_current_directory(&workingData, &workingLength) == false) {
        k_boot_free(workingData as unit*);
        return LoadResult(Source(workingData, 0), sourceMapNew(), false);
    }
    k_boot_free(workingPlaceholder);
    val entryDirectory = loaderDirectory(entryPath, entryPathLength);
    var loader = ModuleLoader(
        loadedModuleListNew(), loadedPathListNew(),
        LoadedPath(workingData, workingLength), entryDirectory);
    val loaded = loaderLoadModule(
        loader, entryPath, entryPathLength, 0,
        workingData, 0, false);
    var combined = byteBufferNew();
    var sourceMap = sourceMapNew();
    if (loaded) {
        var index: u64 = 0;
        while (index < loader.modules.length) {
            val loadedModule = loader.modules.data[index];
            sourceMapAppend(sourceMap, SourceMapSegment(
                loadedModule.path.data, loadedModule.path.length,
                combined.length, loadedModule.length));
            loaderAppend(combined, loadedModule.data, loadedModule.length);
            byteBufferAppend(combined, 10);
            k_boot_free(loadedModule.data as unit*);
            index = index + 1;
        }
    }
    if (loaded == false) {
        var pathIndex: u64 = 0;
        while (pathIndex < loader.visited.length) {
            k_boot_free(loader.visited.data[pathIndex].data as unit*);
            pathIndex = pathIndex + 1;
        }
    }
    k_boot_free(loader.modules.data as unit*);
    k_boot_free(loader.visited.data as unit*);
    k_boot_free(loader.workingDirectory.data as unit*);
    byteBufferFree(loader.entryDirectory);
    if (loaded == false) {
        byteBufferFree(combined);
        sourceMapFree(sourceMap);
        return LoadResult(Source(workingData, 0), sourceMapNew(), false);
    }
    return LoadResult(Source(combined.data, combined.length), sourceMap, true);
}
