module bootstrap.loader;

import bootstrap.source.Source;
import bootstrap.token.Token;
import bootstrap.token.TokenKind;
import bootstrap.list.List;
import bootstrap.containers.ByteBuffer;
import bootstrap.lexer.lex;

extern fn k_boot_current_directory(data: u8**, dataLength: u64*): bool;
extern fn k_boot_canonical_path(path: u8*, pathLength: u64, data: u8**, dataLength: u64*): bool;

struct LoadedPath(data: u8*, length: u64) {

    fn report(val self, source: Source, offset: u64, category: u32) {
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

        message.append(slice(self.data, self.length));
        message.append(":"); loaderAppendNumber(message, line);
        message.append(":"); loaderAppendNumber(message, column);
        message.append(": error: ");

        when (category) {
            1 -> message.append("cannot resolve import");
            2 -> message.append("module import depth exceeded");
            3 -> message.append("unterminated string");
            4 -> message.append("invalid character");
            else -> message.append("invalid source");
        }
        
        message.append("\n");
        k_boot_stderr(message.data, message.length);
    }

}

struct LoadedModule(path: LoadedPath, data: u8*, length: u64)
struct SourceMapSegment(path: u8*, pathLength: u64, sourceStart: u64, sourceLength: u64)
struct LoadResult(source: Source, sourceMap: List<SourceMapSegment>, ok: bool, failureKind: i32)

struct ModuleLoader(
    modules: List<LoadedModule>, visited: List<LoadedPath>,
    workingDirectory: LoadedPath, entryDirectory: ByteBuffer,
    failureKind: i32
) {

    fn visited(val self, path: LoadedPath): bool {
        for (i in 0..<self.visited.length) {
            val other = self.visited.data[i];
            if (loaderBytesEqual(path.data, path.length, other.data, other.length)) return true;
        }

        return false;
    }

    fn resolve_import(
        var self, path: LoadedPath, source: Source,
        val tokens: List<Token>, first: u64, partCount: u64, 
        wildcard: bool, start: u64, end: u64, depth: u64
    ): bool {
        self.failureKind = 2;

        if (depth > 64) {
            self.failureKind = 2;
            path.report(source, start, 2);
            return false;
        }

        if (!wildcard) {
            if (partCount < 2) {
                path.report(source, start, 1);
                return false;
            }
        }

        val relative = loaderRelative(source, tokens, first, partCount, wildcard);
        defer relative.free();

        val currentDirectory = loaderDirectory(slice(path.data, path.length));
        defer currentDirectory.free();

        for (i in 0..<3) {
            val candidate = when (i) {
                0 -> loaderCandidate(
                    slice(
                        self.workingDirectory.data,
                        self.workingDirectory.length),
                    relative
                );
                1 -> loaderCandidate(
                    slice(
                        self.entryDirectory.data,
                        self.entryDirectory.length),
                    relative
                );
                else -> loaderCandidate(
                    slice(currentDirectory.data, currentDirectory.length),
                    relative
                );
            };

            val placeholder = k_boot_alloc(1);
            var data = placeholder as u8*;
            var length: u64 = 0;
            if (loaderReadCandidate(candidate, data, length)) {
                k_boot_free(placeholder);
                val loaded = self.load_module(
                    candidate.data, candidate.length, 
                    depth, data, length, true
                );

                return loaded;
            }
            k_boot_free(placeholder);
        }

        path.report(source, start, 1);

        return false;
    }

    fn scan_imports(var self, path: LoadedPath, source: Source, depth: u64): bool {
        val lexed = lex(source);
        defer lexed.tokens.free();

        if (!lexed.ok) {
            self.failureKind = 2;
            var category: u32 = 4;
            if (lexed.errorKind == 1) category = 3;
            path.report(source, lexed.errorStart, category);
            return false;
        }

        var current: u64 = 0;
        if (lexed.tokens.data[current].kind == TokenKind.KwModule) {
            while (lexed.tokens.data[current].kind != TokenKind.Semicolon) {
                if (lexed.tokens.data[current].kind == TokenKind.EndOfFile) {
                    return false;
                }
                current++;
            }
            current++;
        }

        while (lexed.tokens.data[current].kind == TokenKind.KwImport) {
            val start = lexed.tokens.data[current].start;
            current++;
            val first = current;
            var partCount: u64 = 0;
            var wildcard = false;

            while (lexed.tokens.data[current].kind == TokenKind.Identifier) {
                partCount++;
                current++;

                if (lexed.tokens.data[current].kind == TokenKind.Dot) {
                    current++;

                    if (lexed.tokens.data[current].kind == TokenKind.Star) {
                        wildcard = true;
                        current++;
                        break;
                    }
                } else {
                    break;
                }
            }

            val end = lexed.tokens.data[current].end;
            if (lexed.tokens.data[current].kind != TokenKind.Semicolon) {
                self.failureKind = 2;
                return false;
            }

            current++;

            if (
                !self.resolve_import(
                    path, source, lexed.tokens, first, partCount, 
                    wildcard, start, end, depth + 1
                )
            ) return false;
        }

        return true;
    }

    fn load_module(
        var self, path: u8*, pathLength: u64, depth: u64,
        suppliedData: u8*, suppliedLength: u64, hasSuppliedData: bool
    ): bool {
        if (depth > 64) {
            self.failureKind = 2;
            if (hasSuppliedData) k_boot_free(suppliedData as unit*);
            return false;
        }
        
        val canonicalPlaceholder = k_boot_alloc(1);
        var canonicalData = canonicalPlaceholder as u8*;
        var canonicalLength: u64 = 0;
        if (!k_boot_canonical_path(path, pathLength, &canonicalData, &canonicalLength)) {
            self.failureKind = 1;
            k_boot_free(canonicalData as unit*);
            if (hasSuppliedData) k_boot_free(suppliedData as unit*);
            return false;
        }
        k_boot_free(canonicalPlaceholder);

        val canonical = LoadedPath(canonicalData, canonicalLength);
        if (self.visited(canonical)) {
            k_boot_free(canonical.data as unit*);
            if (hasSuppliedData) k_boot_free(suppliedData as unit*);
            return true;
        }
        self.visited.add(canonical);

        var data = suppliedData;
        var length = suppliedLength;
        if (!hasSuppliedData) {
            val sourcePlaceholder = k_boot_alloc(1);
            data = sourcePlaceholder as u8*;
            length = 0;
            if (!k_boot_read_file(path, pathLength, &data, &length)) {
                self.failureKind = 1;
                k_boot_free(sourcePlaceholder);
                return false;
            }
            k_boot_free(sourcePlaceholder);
        }

        val source = Source(data, length);
        if (!self.scan_imports(canonical, source, depth)) {
            k_boot_free(data as unit*);
            return false;
        }

        self.modules.add(LoadedModule(canonical, data, length));
        return true;
    }

}

fn sourceMapFree(sourceMap: List<SourceMapSegment>) {
    for (i in 0..<sourceMap.length) k_boot_free(sourceMap.data[i].path as unit*);
    sourceMap.free();
}

fn loaderBytesEqual(a: u8*, aLength: u64, b: u8*, bLength: u64): bool {
    if (aLength != bLength) return false;
    for (i in 0..<aLength) if (a[i] != b[i]) return false;
    return true;
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

fn loaderDirectory(val path: []u8): ByteBuffer {
    var end: u64 = 0;
    for (value, cursor in path) {
        if (value == 47) {
            end = cursor;
        } else if (value == 92) {
			end = cursor;
        }
    }

    var result = ByteBuffer.new();
    for (value, index in path) if (index < end) result.add(value);

    return result;
}

fn loaderCandidate(val root: []u8, val relative: ByteBuffer): ByteBuffer {
    var result = ByteBuffer.new();
    result.append(root);
    if (result.length > 0) result.add(47);
    result.append(slice(relative.data, relative.length));
    return result;
}

fn loaderRelative(
    source: Source, val tokens: List<Token>,
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

fn loaderReadCandidate(val candidate: ByteBuffer, var data: u8*, var length: u64) =>
k_boot_read_file(candidate.data, candidate.length, &data, &length);

fn loadModules(entryPath: u8*, entryPathLength: u64): LoadResult {
    val workingPlaceholder = k_boot_alloc(1);
    var workingData = workingPlaceholder as u8*;
    var workingLength: u64 = 0;
    if (!k_boot_current_directory(&workingData, &workingLength)) {
        k_boot_free(workingData as unit*);
        return LoadResult(Source(workingData, 0), List<SourceMapSegment>.new(), false, 1);
    }
    k_boot_free(workingPlaceholder);
    val entryDirectory = loaderDirectory(slice(entryPath, entryPathLength));
    var loader = ModuleLoader(
        List<LoadedModule>.new(), List<LoadedPath>.new(),
        LoadedPath(workingData, workingLength), entryDirectory, 1
    );
    val loaded = loader.load_module(
        entryPath, entryPathLength, 0,
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
            combined.append(slice(loadedModule.data, loadedModule.length));
            combined.add(10);
            k_boot_free(loadedModule.data as unit*);
        }
    }
    else for (i in 0..<loader.visited.length) k_boot_free(loader.visited.data[i].data as unit*);

    val failureKind = loader.failureKind;
    k_boot_free(loader.modules.data as unit*);
    k_boot_free(loader.visited.data as unit*);
    k_boot_free(loader.workingDirectory.data as unit*);
    k_boot_free(loader.entryDirectory.data as unit*);

    if (!loaded) {
        sourceMap.free();
        combined.free();
        return LoadResult(Source(workingData, 0), List<SourceMapSegment>.new(), false, failureKind);
    }

    val sourceData = k_boot_alloc(combined.length) as u8*;
    for (i in 0..<combined.length) sourceData[i] = combined.data[i];
    return LoadResult(Source(sourceData, combined.length), sourceMap, true, 0);
}
