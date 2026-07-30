module bootstrap.loader;

import bootstrap.source.Source;
import bootstrap.token.Token;
import bootstrap.list.List;
import bootstrap.containers.ByteBuffer;
import bootstrap.lexer.lex;

extern fn k_boot_current_directory(data: u8**, dataLength: u64*): bool;
extern fn k_boot_canonical_path(path: u8*, pathLength: u64, data: u8**, dataLength: u64*): bool;

struct LoadedPath(data: u8*, length: u64)
struct LoadedModule(path: LoadedPath, data: u8*, length: u64)
struct SourceMapSegment(path: u8*, pathLength: u64, sourceStart: u64, sourceLength: u64)
struct LoadResult(source: Source, sourceMap: List<SourceMapSegment>, ok: bool, failureKind: i32)
struct ModuleLoader(
    modules: List<LoadedModule>,
    visited: List<LoadedPath>,
    workingDirectory: LoadedPath,
    entryDirectory: ByteBuffer,
    failureKind: i32
)

fn sourceMapFree(sourceMap: List<SourceMapSegment>) {
    for (i in 0..<sourceMap.length) k_boot_free(sourceMap.data[i].path as unit*);
    sourceMap.free();
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
    for (i in 0..<length) buffer.add(data[i]);
}

fn loaderAppendNumber(var buffer: ByteBuffer, value: u64) {
    var digits = ByteBuffer.new();
    defer digits.free();
    var current = value;
    if (current == 0) digits.add(48);
    while (current > 0) {
        digits.add(48 + (current % 10) as u8);
        current /= 10;
    }
    for (i in digits.length>..0) buffer.add(digits.data[i]);
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
    var message = ByteBuffer.new();
    defer message.free();
    loaderAppend(message, path.data, path.length);
    message.add(58); loaderAppendNumber(message, line);
    message.add(58); loaderAppendNumber(message, column);
    message.add(58); message.add(32);
    message.add(101); message.add(114);
    message.add(114); message.add(111);
    message.add(114); message.add(58);
    message.add(32);

    when (category) {
        1 -> {
            message.add(99); message.add(97);
            message.add(110); message.add(110);
            message.add(111); message.add(116);
            message.add(32); message.add(114);
            message.add(101); message.add(115);
            message.add(111); message.add(108);
            message.add(118); message.add(101);
            message.add(32); message.add(105);
            message.add(109); message.add(112);
            message.add(111); message.add(114);
            message.add(116);
        }
        2 -> {
            message.add(109); message.add(111);
            message.add(100); message.add(117);
            message.add(108); message.add(101);
            message.add(32); message.add(105);
            message.add(109); message.add(112);
            message.add(111); message.add(114);
            message.add(116); message.add(32);
            message.add(100); message.add(101);
            message.add(112); message.add(116);
            message.add(104); message.add(32);
            message.add(101); message.add(120);
            message.add(99); message.add(101);
            message.add(101); message.add(100);
            message.add(101); message.add(100);
        }
        3 -> {
            message.add(117); message.add(110);
            message.add(116); message.add(101);
            message.add(114); message.add(109);
            message.add(105); message.add(110);
            message.add(97); message.add(116);
            message.add(101); message.add(100);
            message.add(32); message.add(115);
            message.add(116); message.add(114);
            message.add(105); message.add(110);
            message.add(103);
        }
        4 -> {
            message.add(105); message.add(110);
            message.add(118); message.add(97);
            message.add(108); message.add(105);
            message.add(100); message.add(32);
            message.add(99); message.add(104);
            message.add(97); message.add(114);
            message.add(97); message.add(99);
            message.add(116); message.add(101);
            message.add(114);
        }
        else -> {
            message.add(105); message.add(110);
            message.add(118); message.add(97);
            message.add(108); message.add(105);
            message.add(100); message.add(32);
            message.add(115); message.add(111);
            message.add(117); message.add(114);
            message.add(99); message.add(101);
        }
    }
    
    message.add(10);
    k_boot_stderr(message.data, message.length);
}

fn loaderDirectory(path: u8*, length: u64): ByteBuffer {
    var end: u64 = 0;
    for (cursor in length>..0) {
        val value = path[cursor];
        if (value == 47) {
            end = cursor;
            break;
        } else if (value == 92) {
			end = cursor;
			break;
        }
    }

    var result = ByteBuffer.new();
    loaderAppend(result, path, end);

    return result;
}

fn loaderCandidate(root: u8*, rootLength: u64, relative: ByteBuffer): ByteBuffer {
    var result = ByteBuffer.new();
    loaderAppend(result, root, rootLength);
    if (rootLength > 0) result.add(47);
    loaderAppend(result, relative.data, relative.length);
    return result;
}

fn loaderRelative(
    source: Source, tokens: List<Token>,
    first: u64, partCount: u64,
    wildcard: bool
): ByteBuffer {
    var result = ByteBuffer.new();
    var count = partCount;
    if (!wildcard) count--;

    for (i in 0..<count) {
        if (i > 0) result.add(47);
        val token = tokens.data[first + i * 2];
        for (j in token.start..<token.end) result.add(source.data[j]);
    }

    if (wildcard) {
        result.add(47);
        result.add(109); result.add(111);
        result.add(100); result.add(46);
        result.add(107);
    } else {
        result.add(46);
        result.add(107);
    }

    return result;
}

fn loaderReadCandidate(candidate: ByteBuffer, var data: u8*, var length: u64) =>
k_boot_read_file(candidate.data, candidate.length, &data, &length);

fn loaderResolveImport(
    var loader: ModuleLoader, currentPath: LoadedPath, source: Source,
    tokens: List<Token>, first: u64, partCount: u64, wildcard: bool,
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
    defer relative.free();
    val currentDirectory = loaderDirectory(currentPath.data, currentPath.length);
    defer currentDirectory.free();
    for (i in 0..<3) {
        var candidate = ByteBuffer.new();
        defer candidate.free();
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

            return loaded;
        }
        k_boot_free(placeholder);
    }

    loaderReport(currentPath, source, start, 1);

    return false;
}

fn loaderScanImports(
    var loader: ModuleLoader, path: LoadedPath,
    source: Source, depth: u64
): bool {
    val lexed = lex(source);
    defer lexed.tokens.free();
    if (!lexed.ok) {
        loader.failureKind = 2;
        var category: u32 = 4;
        if (lexed.errorKind == 1) category = 3;
        loaderReport(path, source, lexed.errorStart, category);
        return false;
    }
    val tokens = lexed.tokens;
    var current: u64 = 0;
    if (tokens.data[current].kind == 25) {
        while (tokens.data[current].kind != 58) {
            if (tokens.data[current].kind == 0) {
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
        while (tokens.data[current].kind == 1) {
            partCount++;
            current++;
            if (tokens.data[current].kind == 59) {
                current++;
                if (tokens.data[current].kind == 62) {
                    wildcard = true;
                    current++;
                    break;
                }
            } else {
                break;
            }
        }
        val end = tokens.data[current].end;
        if (tokens.data[current].kind != 58) {
            loader.failureKind = 2;
            return false;
        }
        current++;
        if (
            !loaderResolveImport(
                loader, path, source, tokens, first, partCount, wildcard,
                start, end, depth + 1
            )
        ) {
            return false;
        }
    }

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
    visited.add(canonical);
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
    modules.add(LoadedModule(canonical, data, length));
    loader.modules = modules;
    return true;
}

fn loadModules(entryPath: u8*, entryPathLength: u64): LoadResult {
    val workingPlaceholder = k_boot_alloc(1);
    var workingData = workingPlaceholder as u8*;
    var workingLength: u64 = 0;
    if (!k_boot_current_directory(&workingData, &workingLength)) {
        k_boot_free(workingData as unit*);
        return LoadResult(Source(workingData, 0), List<SourceMapSegment>.new(), false, 1);
    }
    k_boot_free(workingPlaceholder);
    val entryDirectory = loaderDirectory(entryPath, entryPathLength);
    var loader = ModuleLoader(
        List<LoadedModule>.new(), List<LoadedPath>.new(),
        LoadedPath(workingData, workingLength), entryDirectory, 1
    );
    val loaded = loaderLoadModule(
        loader, entryPath, entryPathLength, 0,
        workingData, 0, false
    );
    var combined = ByteBuffer.new();
    var sourceMap = List<SourceMapSegment>.new();

    if (loaded) {
        for (i in 0..<loader.modules.length) {
            val loadedModule = loader.modules.data[i];
            sourceMap.add(
                SourceMapSegment(
	                loadedModule.path.data, loadedModule.path.length,
	                combined.length, loadedModule.length
                )
            );
            loaderAppend(combined, loadedModule.data, loadedModule.length);
            combined.add(10);
            k_boot_free(loadedModule.data as unit*);
        }
    }
    else for (i in 0..<loader.visited.length) k_boot_free(loader.visited.data[i].data as unit*);

    loader.modules.free();
    loader.visited.free();
    k_boot_free(loader.workingDirectory.data as unit*);
    loader.entryDirectory.free();

    if (!loaded) {
        combined.free();
        sourceMapFree(sourceMap);
        return LoadResult(Source(workingData, 0), List<SourceMapSegment>.new(), false, loader.failureKind);
    }

    return LoadResult(Source(combined.data, combined.length), sourceMap, true, 0);
}
