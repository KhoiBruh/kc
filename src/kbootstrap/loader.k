module kbootstrap.loader;

import kbootstrap.source.Source;
import kbootstrap.token.Token;
import kbootstrap.containers.ByteBuffer;
import kbootstrap.lexer.lex;

extern fn k_boot_current_directory(data: u8**, dataLength: u64*): bool;
extern fn k_boot_canonical_path(path: u8*, pathLength: u64, data: u8**, dataLength: u64*): bool;

struct LoadedPath(data: u8*, length: u64)
struct LoadedPathList(data: LoadedPath*, length: u64, capacity: u64)
struct LoadedModule(path: LoadedPath, data: u8*, length: u64)
struct LoadedModuleList(data: LoadedModule*, length: u64, capacity: u64)
struct SourceMapSegment(path: u8*, pathLength: u64, sourceStart: u64, sourceLength: u64)
struct SourceMap(data: SourceMapSegment*, length: u64, capacity: u64)
struct LoadResult(source: Source, sourceMap: SourceMap, ok: bool, failureKind: i32)
struct ModuleLoader(
    modules: LoadedModuleList,
    visited: LoadedPathList,
    workingDirectory: LoadedPath,
    entryDirectory: ByteBuffer,
    failureKind: i32
)

fn loadedModuleListNew() => LoadedModuleList(k_boot_alloc(2 * sizeof(LoadedModule)) as LoadedModule*, 0, 2);

fn loadedModuleListAppend(var list: LoadedModuleList, loadedModule: LoadedModule) {
    if (list.length == list.capacity) {
        val capacity = list.capacity * 2;
        val data = k_boot_alloc(capacity * sizeof(LoadedModule)) as LoadedModule*;
        for (i in 0..<list.length) data[i] = list.data[i];
        k_boot_free(list.data as unit*);
        list.data = data;
        list.capacity = capacity;
    }
    list.data[list.length] = loadedModule;
    list.length++;
}

fn loadedPathListNew() => LoadedPathList(k_boot_alloc(2 * sizeof(LoadedPath)) as LoadedPath*, 0, 2);

fn loadedPathListAppend(var list: LoadedPathList, path: LoadedPath) {
    if (list.length == list.capacity) {
        val capacity = list.capacity * 2;
        val data = k_boot_alloc(capacity * sizeof(LoadedPath)) as LoadedPath*;
        for (i in 0..<list.length) data[i] = list.data[i];
        k_boot_free(list.data as unit*);
        list.data = data;
        list.capacity = capacity;
    }
    list.data[list.length] = path;
    list.length++;
}

fn sourceMapNew() => SourceMap(k_boot_alloc(2 * sizeof(SourceMapSegment)) as SourceMapSegment*, 0, 2);

fn sourceMapAppend(var sourceMap: SourceMap, segment: SourceMapSegment) {
    if (sourceMap.length == sourceMap.capacity) {
        val capacity = sourceMap.capacity * 2;
        val data = k_boot_alloc(capacity * sizeof(SourceMapSegment)) as SourceMapSegment*;
        for (i in 0..<sourceMap.length) data[i] = sourceMap.data[i];
        k_boot_free(sourceMap.data as unit*);
        sourceMap.data = data;
        sourceMap.capacity = capacity;
    }
    sourceMap.data[sourceMap.length] = segment;
    sourceMap.length++;
}

fn sourceMapFree(sourceMap: SourceMap) {
    for (i in 0..<sourceMap.length) k_boot_free(sourceMap.data[i].path as unit*);
    k_boot_free(sourceMap.data as unit*);
}

fn loaderBytesEqual(a: u8*, aLength: u64, b: u8*, bLength: u64): bool {
    if (aLength != bLength) return false;
    for (i in 0..<aLength) if (a[i] != b[i]) return false;
    return true;
}

fn loaderWasVisited(loader: ModuleLoader, path: LoadedPath): bool {
    for (i in 0..<loader.visited.length) {
        val other = loader.visited.data[i];
        if (loaderBytesEqual(path.data, path.length, other.data, other.length)) return true;
    }
    return false;
}

fn loaderAppend(var buffer: ByteBuffer, data: u8*, length: u64) {
    for (i in 0..<length) byteBufferAppend(buffer, data[i]);
}

fn loaderAppendNumber(var buffer: ByteBuffer, value: u64) {
    var digits = byteBufferNew();
    var current = value;
    if (current == 0) byteBufferAppend(digits, 48);
    while (current > 0) {
        byteBufferAppend(digits, 48 + (current % 10) as u8);
        current /= 10;
    }
    for (i in digits.length>..0) byteBufferAppend(buffer, digits.data[i]);
    byteBufferFree(digits);
}

fn loaderReport(path: LoadedPath, source: Source, offset: u64, category: u32) {
    var line: u64 = 1;
    var column: u64 = 1;
    for (i in 0..<offset) {
        if (source.data[i] == 10) {
            line++;
            column = 1;
        }
        else column++;
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

    when (category) {
        1 -> {
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
        }
        2 -> {
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
        }
        3 -> {
            byteBufferAppend(message, 117); byteBufferAppend(message, 110);
            byteBufferAppend(message, 116); byteBufferAppend(message, 101);
            byteBufferAppend(message, 114); byteBufferAppend(message, 109);
            byteBufferAppend(message, 105); byteBufferAppend(message, 110);
            byteBufferAppend(message, 97); byteBufferAppend(message, 116);
            byteBufferAppend(message, 101); byteBufferAppend(message, 100);
            byteBufferAppend(message, 32); byteBufferAppend(message, 115);
            byteBufferAppend(message, 116); byteBufferAppend(message, 114);
            byteBufferAppend(message, 105); byteBufferAppend(message, 110);
            byteBufferAppend(message, 103);
        }
        4 -> {
            byteBufferAppend(message, 105); byteBufferAppend(message, 110);
            byteBufferAppend(message, 118); byteBufferAppend(message, 97);
            byteBufferAppend(message, 108); byteBufferAppend(message, 105);
            byteBufferAppend(message, 100); byteBufferAppend(message, 32);
            byteBufferAppend(message, 99); byteBufferAppend(message, 104);
            byteBufferAppend(message, 97); byteBufferAppend(message, 114);
            byteBufferAppend(message, 97); byteBufferAppend(message, 99);
            byteBufferAppend(message, 116); byteBufferAppend(message, 101);
            byteBufferAppend(message, 114);
        }
        else -> {
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
            cursor--;
            val value = path[cursor];
            if (value == 47) {
                end = cursor;
                searching = false;
            } else if (value == 92) {
				end = cursor;
				searching = false;
            }
        }
        else cursor = 0;
    }

    var result = byteBufferNew();
    loaderAppend(result, path, end);

    return result;
}

fn loaderCandidate(root: u8*, rootLength: u64, relative: ByteBuffer): ByteBuffer {
    var result = byteBufferNew();
    loaderAppend(result, root, rootLength);
    if (rootLength > 0) byteBufferAppend(result, 47);
    loaderAppend(result, relative.data, relative.length);
    return result;
}

fn loaderRelative(
    source: Source, tokens: TokenList,
    first: u64, partCount: u64,
    wildcard: bool
): ByteBuffer {
    var result = byteBufferNew();
    var count = partCount;
    if (!wildcard) count--;

    for (i in 0..<count) {
        if (i > 0) byteBufferAppend(result, 47);
        val token = tokens.data[first + i * 2];
        for (j in token.start..<token.end) byteBufferAppend(result, source.data[j]);
    }

    if (wildcard) {
        byteBufferAppend(result, 47);
        byteBufferAppend(result, 109); byteBufferAppend(result, 111);
        byteBufferAppend(result, 100); byteBufferAppend(result, 46);
        byteBufferAppend(result, 107);
    } else {
        byteBufferAppend(result, 46);
        byteBufferAppend(result, 107);
    }

    return result;
}

fn loaderReadCandidate(candidate: ByteBuffer, var data: u8*, var length: u64) =>
k_boot_read_file(candidate.data, candidate.length, &data, &length);

fn loaderResolveImport(
    var loader: ModuleLoader, currentPath: LoadedPath, source: Source,
    tokens: TokenList, first: u64, partCount: u64, wildcard: bool,
    start: u64, end: u64, depth: u64
): bool {
    loader.failureKind = 2;
    if (depth > 64) {
        loader.failureKind = 2;
        loaderReport(currentPath, source, start, 2);
        return false;
    }
    if (!wildcard) {
        if (partCount < 2) {
            loaderReport(currentPath, source, start, 1);
            return false;
        }
    }
    val relative = loaderRelative(source, tokens, first, partCount, wildcard);
    val currentDirectory = loaderDirectory(currentPath.data, currentPath.length);
    for (i in 0..<3) {
        var candidate = byteBufferNew();
        candidate = when (i) {
            0 -> loaderCandidate(
				loader.workingDirectory.data,
				loader.workingDirectory.length,
				relative
			);
			1 -> loaderCandidate(
				loader.entryDirectory.data,
				loader.entryDirectory.length,
				relative
			);
			else -> loaderCandidate(
				currentDirectory.data,
				currentDirectory.length,
				relative
			);
        };

        val placeholder = k_boot_alloc(1);
        var data = placeholder as u8*;
        var length: u64 = 0;
        if (loaderReadCandidate(candidate, data, length)) {
            k_boot_free(placeholder);
            val loaded = loaderLoadModule(
                loader, candidate.data, candidate.length, depth,
                data, length, true
            );
            byteBufferFree(candidate);
            byteBufferFree(currentDirectory);
            byteBufferFree(relative);
            return loaded;
        }
        k_boot_free(placeholder);
        byteBufferFree(candidate);
    }

    byteBufferFree(currentDirectory);
    byteBufferFree(relative);
    loaderReport(currentPath, source, start, 1);

    return false;
}

fn loaderScanImports(
    var loader: ModuleLoader, path: LoadedPath,
    source: Source, depth: u64
): bool {
    val lexed = lex(source);
    if (!lexed.ok) {
        loader.failureKind = 2;
        var category: u32 = 4;
        if (lexed.errorKind == 1) category = 3;
        loaderReport(path, source, lexed.errorStart, category);
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
            current++;
        }
        current++;
    }
    while (tokens.data[current].kind == 26) {
        val start = tokens.data[current].start;
        current++;
        val first = current;
        var partCount: u64 = 0;
        var wildcard = false;
        var scanning = true;
        while (scanning) {
            if (tokens.data[current].kind != 1) {
                scanning = false;
            } else {
                partCount++;
                current++;
                if (tokens.data[current].kind == 59) {
                    current++;
                    if (tokens.data[current].kind == 62) {
                        wildcard = true;
                        current++;
                        scanning = false;
                    }
                } else {
                    scanning = false;
                }
            }
        }
        val end = tokens.data[current].end;
        if (tokens.data[current].kind != 58) {
            loader.failureKind = 2;
            tokenListFree(tokens);
            return false;
        }
        current++;
        if (
            !loaderResolveImport(
                loader, path, source, tokens, first, partCount, wildcard,
                start, end, depth + 1
            )
        ) {
            tokenListFree(tokens);
            return false;
        }
    }

    tokenListFree(tokens);

    return true;
}

fn loaderLoadModule(
    var loader: ModuleLoader, path: u8*, pathLength: u64, depth: u64,
    suppliedData: u8*, suppliedLength: u64, hasSuppliedData: bool
): bool {
    if (depth > 64) {
        loader.failureKind = 2;
        if (hasSuppliedData) k_boot_free(suppliedData as unit*);
        return false;
    }
    val canonicalPlaceholder = k_boot_alloc(1);
    var canonicalData = canonicalPlaceholder as u8*;
    var canonicalLength: u64 = 0;
    if (!k_boot_canonical_path(path, pathLength, &canonicalData, &canonicalLength)) {
        loader.failureKind = 1;
        k_boot_free(canonicalData as unit*);
        if (hasSuppliedData) k_boot_free(suppliedData as unit*);
        return false;
    }
    k_boot_free(canonicalPlaceholder);
    val canonical = LoadedPath(canonicalData, canonicalLength);
    if (loaderWasVisited(loader, canonical)) {
        k_boot_free(canonical.data as unit*);
        if (hasSuppliedData) k_boot_free(suppliedData as unit*);
        return true;
    }
    var visited = loader.visited;
    loadedPathListAppend(visited, canonical);
    loader.visited = visited;
    var data = suppliedData;
    var length = suppliedLength;
    if (!hasSuppliedData) {
        val sourcePlaceholder = k_boot_alloc(1);
        data = sourcePlaceholder as u8*;
        length = 0;
        if (!k_boot_read_file(path, pathLength, &data, &length)) {
            loader.failureKind = 1;
            k_boot_free(sourcePlaceholder);
            return false;
        }
        k_boot_free(sourcePlaceholder);
    }
    val source = Source(data, length);
    if (!loaderScanImports(loader, canonical, source, depth)) {
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
    if (!k_boot_current_directory(&workingData, &workingLength)) {
        k_boot_free(workingData as unit*);
        return LoadResult(Source(workingData, 0), sourceMapNew(), false, 1);
    }
    k_boot_free(workingPlaceholder);
    val entryDirectory = loaderDirectory(entryPath, entryPathLength);
    var loader = ModuleLoader(
        loadedModuleListNew(), loadedPathListNew(),
        LoadedPath(workingData, workingLength), entryDirectory, 1
    );
    val loaded = loaderLoadModule(
        loader, entryPath, entryPathLength, 0,
        workingData, 0, false
    );
    var combined = byteBufferNew();
    var sourceMap = sourceMapNew();

    if (loaded) {
        for (i in 0..<loader.modules.length) {
            val loadedModule = loader.modules.data[i];
            sourceMapAppend(
                sourceMap,
                SourceMapSegment(
	                loadedModule.path.data, loadedModule.path.length,
	                combined.length, loadedModule.length
                )
            );
            loaderAppend(combined, loadedModule.data, loadedModule.length);
            byteBufferAppend(combined, 10);
            k_boot_free(loadedModule.data as unit*);
        }
    }
    else for (i in 0..<loader.visited.length) k_boot_free(loader.visited.data[i].data as unit*);

    k_boot_free(loader.modules.data as unit*);
    k_boot_free(loader.visited.data as unit*);
    k_boot_free(loader.workingDirectory.data as unit*);
    byteBufferFree(loader.entryDirectory);

    if (!loaded) {
        byteBufferFree(combined);
        sourceMapFree(sourceMap);
        return LoadResult(Source(workingData, 0), sourceMapNew(), false, loader.failureKind);
    }

    return LoadResult(Source(combined.data, combined.length), sourceMap, true, 0);
}
