pragma solidity >= 0.7.6;
pragma abicoder v2;


library strings {
    struct slice {
        uint _len;
        uint _ptr;
    }

    function memcpy(uint dest, uint src, uint len) private pure {
        // Copy word-length chunks while possible
        for(; len >= 32; len -= 32) {
            assembly {
                mstore(dest, mload(src))
            }
            dest += 32;
            src += 32;
        }

        // Copy remaining bytes
        uint mask = type(uint).max;
        if (len > 0) {
            mask = 256 ** (32 - len) - 1;
        }
        assembly {
            let srcpart := and(mload(src), not(mask))
            let destpart := and(mload(dest), mask)
            mstore(dest, or(destpart, srcpart))
        }
    }

    /*
     * @dev Returns a slice containing the entire string.
     * @param self The string to make a slice from.
     * @return A newly allocated slice containing the entire string.
     */
    function toSlice(string memory self) internal pure returns (slice memory) {
        uint ptr;
        assembly {
            ptr := add(self, 0x20)
        }
        return slice(bytes(self).length, ptr);
    }

    /*
     * @dev Returns the length of a null-terminated bytes32 string.
     * @param self The value to find the length of.
     * @return The length of the string, from 0 to 32.
     */
    function len(bytes32 self) internal pure returns (uint) {
        uint ret;
        if (self == 0)
            return 0;
        if (uint(self) & type(uint128).max == 0) {
            ret += 16;
            self = bytes32(uint(self) / 0x100000000000000000000000000000000);
        }
        if (uint(self) & type(uint64).max == 0) {
            ret += 8;
            self = bytes32(uint(self) / 0x10000000000000000);
        }
        if (uint(self) & type(uint32).max == 0) {
            ret += 4;
            self = bytes32(uint(self) / 0x100000000);
        }
        if (uint(self) & type(uint16).max == 0) {
            ret += 2;
            self = bytes32(uint(self) / 0x10000);
        }
        if (uint(self) & type(uint8).max == 0) {
            ret += 1;
        }
        return 32 - ret;
    }

    /*
     * @dev Returns a slice containing the entire bytes32, interpreted as a
     *      null-terminated utf-8 string.
     * @param self The bytes32 value to convert to a slice.
     * @return A new slice containing the value of the input argument up to the
     *         first null.
     */
    function toSliceB32(bytes32 self) internal pure returns (slice memory ret) {
        // Allocate space for `self` in memory, copy it there, and point ret at it
        assembly {
            let ptr := mload(0x40)
            mstore(0x40, add(ptr, 0x20))
            mstore(ptr, self)
            mstore(add(ret, 0x20), ptr)
        }
        ret._len = len(self);
    }

    /*
     * @dev Returns a new slice containing the same data as the current slice.
     * @param self The slice to copy.
     * @return A new slice containing the same data as `self`.
     */
    function copy(slice memory self) internal pure returns (slice memory) {
        return slice(self._len, self._ptr);
    }

    /*
     * @dev Copies a slice to a new string.
     * @param self The slice to copy.
     * @return A newly allocated string containing the slice's text.
     */
    function toString(slice memory self) internal pure returns (string memory) {
        string memory ret = new string(self._len);
        uint retptr;
        assembly { retptr := add(ret, 32) }

        memcpy(retptr, self._ptr, self._len);
        return ret;
    }

    /*
     * @dev Returns the length in runes of the slice. Note that this operation
     *      takes time proportional to the length of the slice; avoid using it
     *      in loops, and call `slice.empty()` if you only need to know whether
     *      the slice is empty or not.
     * @param self The slice to operate on.
     * @return The length of the slice in runes.
     */
    function len(slice memory self) internal pure returns (uint l) {
        // Starting at ptr-31 means the LSB will be the byte we care about
        uint ptr = self._ptr - 31;
        uint end = ptr + self._len;
        for (l = 0; ptr < end; l++) {
            uint8 b;
            assembly { b := and(mload(ptr), 0xFF) }
            if (b < 0x80) {
                ptr += 1;
            } else if(b < 0xE0) {
                ptr += 2;
            } else if(b < 0xF0) {
                ptr += 3;
            } else if(b < 0xF8) {
                ptr += 4;
            } else if(b < 0xFC) {
                ptr += 5;
            } else {
                ptr += 6;
            }
        }
    }

    /*
     * @dev Returns true if the slice is empty (has a length of 0).
     * @param self The slice to operate on.
     * @return True if the slice is empty, False otherwise.
     */
    function empty(slice memory self) internal pure returns (bool) {
        return self._len == 0;
    }

    /*
     * @dev Returns a positive number if `other` comes lexicographically after
     *      `self`, a negative number if it comes before, or zero if the
     *      contents of the two slices are equal. Comparison is done per-rune,
     *      on unicode codepoints.
     * @param self The first slice to compare.
     * @param other The second slice to compare.
     * @return The result of the comparison.
     */
    function compare(slice memory self, slice memory other) internal pure returns (int) {
        uint shortest = self._len;
        if (other._len < self._len)
            shortest = other._len;

        uint selfptr = self._ptr;
        uint otherptr = other._ptr;
        for (uint idx = 0; idx < shortest; idx += 32) {
            uint a;
            uint b;
            assembly {
                a := mload(selfptr)
                b := mload(otherptr)
            }
            if (a != b) {
                // Mask out irrelevant bytes and check again
                uint mask = type(uint).max; // 0xffff...
                if(shortest < 32) {
                  mask = ~(2 ** (8 * (32 - shortest + idx)) - 1);
                }
                unchecked {
                    uint diff = (a & mask) - (b & mask);
                    if (diff != 0)
                        return int(diff);
                }
            }
            selfptr += 32;
            otherptr += 32;
        }
        return int(self._len) - int(other._len);
    }

    /*
     * @dev Returns true if the two slices contain the same text.
     * @param self The first slice to compare.
     * @param self The second slice to compare.
     * @return True if the slices are equal, false otherwise.
     */
    function equals(slice memory self, slice memory other) internal pure returns (bool) {
        return compare(self, other) == 0;
    }

    /*
     * @dev Extracts the first rune in the slice into `rune`, advancing the
     *      slice to point to the next rune and returning `self`.
     * @param self The slice to operate on.
     * @param rune The slice that will contain the first rune.
     * @return `rune`.
     */
    function nextRune(slice memory self, slice memory rune) internal pure returns (slice memory) {
        rune._ptr = self._ptr;

        if (self._len == 0) {
            rune._len = 0;
            return rune;
        }

        uint l;
        uint b;
        // Load the first byte of the rune into the LSBs of b
        assembly { b := and(mload(sub(mload(add(self, 32)), 31)), 0xFF) }
        if (b < 0x80) {
            l = 1;
        } else if(b < 0xE0) {
            l = 2;
        } else if(b < 0xF0) {
            l = 3;
        } else {
            l = 4;
        }

        // Check for truncated codepoints
        if (l > self._len) {
            rune._len = self._len;
            self._ptr += self._len;
            self._len = 0;
            return rune;
        }

        self._ptr += l;
        self._len -= l;
        rune._len = l;
        return rune;
    }

    /*
     * @dev Returns the first rune in the slice, advancing the slice to point
     *      to the next rune.
     * @param self The slice to operate on.
     * @return A slice containing only the first rune from `self`.
     */
    function nextRune(slice memory self) internal pure returns (slice memory ret) {
        nextRune(self, ret);
    }

    /*
     * @dev Returns the number of the first codepoint in the slice.
     * @param self The slice to operate on.
     * @return The number of the first codepoint in the slice.
     */
    function ord(slice memory self) internal pure returns (uint ret) {
        if (self._len == 0) {
            return 0;
        }

        uint word;
        uint length;
        uint divisor = 2 ** 248;

        // Load the rune into the MSBs of b
        assembly { word:= mload(mload(add(self, 32))) }
        uint b = word / divisor;
        if (b < 0x80) {
            ret = b;
            length = 1;
        } else if(b < 0xE0) {
            ret = b & 0x1F;
            length = 2;
        } else if(b < 0xF0) {
            ret = b & 0x0F;
            length = 3;
        } else {
            ret = b & 0x07;
            length = 4;
        }

        // Check for truncated codepoints
        if (length > self._len) {
            return 0;
        }

        for (uint i = 1; i < length; i++) {
            divisor = divisor / 256;
            b = (word / divisor) & 0xFF;
            if (b & 0xC0 != 0x80) {
                // Invalid UTF-8 sequence
                return 0;
            }
            ret = (ret * 64) | (b & 0x3F);
        }

        return ret;
    }

    /*
     * @dev Returns the keccak-256 hash of the slice.
     * @param self The slice to hash.
     * @return The hash of the slice.
     */
    function keccak(slice memory self) internal pure returns (bytes32 ret) {
        assembly {
            ret := keccak256(mload(add(self, 32)), mload(self))
        }
    }

    /*
     * @dev Returns true if `self` starts with `needle`.
     * @param self The slice to operate on.
     * @param needle The slice to search for.
     * @return True if the slice starts with the provided text, false otherwise.
     */
    function startsWith(slice memory self, slice memory needle) internal pure returns (bool) {
        if (self._len < needle._len) {
            return false;
        }

        if (self._ptr == needle._ptr) {
            return true;
        }

        bool equal;
        assembly {
            let length := mload(needle)
            let selfptr := mload(add(self, 0x20))
            let needleptr := mload(add(needle, 0x20))
            equal := eq(keccak256(selfptr, length), keccak256(needleptr, length))
        }
        return equal;
    }

    /*
     * @dev If `self` starts with `needle`, `needle` is removed from the
     *      beginning of `self`. Otherwise, `self` is unmodified.
     * @param self The slice to operate on.
     * @param needle The slice to search for.
     * @return `self`
     */
    function beyond(slice memory self, slice memory needle) internal pure returns (slice memory) {
        if (self._len < needle._len) {
            return self;
        }

        bool equal = true;
        if (self._ptr != needle._ptr) {
            assembly {
                let length := mload(needle)
                let selfptr := mload(add(self, 0x20))
                let needleptr := mload(add(needle, 0x20))
                equal := eq(keccak256(selfptr, length), keccak256(needleptr, length))
            }
        }

        if (equal) {
            self._len -= needle._len;
            self._ptr += needle._len;
        }

        return self;
    }

    /*
     * @dev Returns true if the slice ends with `needle`.
     * @param self The slice to operate on.
     * @param needle The slice to search for.
     * @return True if the slice starts with the provided text, false otherwise.
     */
    function endsWith(slice memory self, slice memory needle) internal pure returns (bool) {
        if (self._len < needle._len) {
            return false;
        }

        uint selfptr = self._ptr + self._len - needle._len;

        if (selfptr == needle._ptr) {
            return true;
        }

        bool equal;
        assembly {
            let length := mload(needle)
            let needleptr := mload(add(needle, 0x20))
            equal := eq(keccak256(selfptr, length), keccak256(needleptr, length))
        }

        return equal;
    }

    /*
     * @dev If `self` ends with `needle`, `needle` is removed from the
     *      end of `self`. Otherwise, `self` is unmodified.
     * @param self The slice to operate on.
     * @param needle The slice to search for.
     * @return `self`
     */
    function until(slice memory self, slice memory needle) internal pure returns (slice memory) {
        if (self._len < needle._len) {
            return self;
        }

        uint selfptr = self._ptr + self._len - needle._len;
        bool equal = true;
        if (selfptr != needle._ptr) {
            assembly {
                let length := mload(needle)
                let needleptr := mload(add(needle, 0x20))
                equal := eq(keccak256(selfptr, length), keccak256(needleptr, length))
            }
        }

        if (equal) {
            self._len -= needle._len;
        }

        return self;
    }

    // Returns the memory address of the first byte of the first occurrence of
    // `needle` in `self`, or the first byte after `self` if not found.
    function findPtr(uint selflen, uint selfptr, uint needlelen, uint needleptr) private pure returns (uint) {
        uint ptr = selfptr;
        uint idx;

        if (needlelen <= selflen) {
            if (needlelen <= 32) {
                bytes32 mask;
                if (needlelen > 0) {
                    mask = bytes32(~(2 ** (8 * (32 - needlelen)) - 1));
                }

                bytes32 needledata;
                assembly { needledata := and(mload(needleptr), mask) }

                uint end = selfptr + selflen - needlelen;
                bytes32 ptrdata;
                assembly { ptrdata := and(mload(ptr), mask) }

                while (ptrdata != needledata) {
                    if (ptr >= end)
                        return selfptr + selflen;
                    ptr++;
                    assembly { ptrdata := and(mload(ptr), mask) }
                }
                return ptr;
            } else {
                // For long needles, use hashing
                bytes32 hash;
                assembly { hash := keccak256(needleptr, needlelen) }

                for (idx = 0; idx <= selflen - needlelen; idx++) {
                    bytes32 testHash;
                    assembly { testHash := keccak256(ptr, needlelen) }
                    if (hash == testHash)
                        return ptr;
                    ptr += 1;
                }
            }
        }
        return selfptr + selflen;
    }

    // Returns the memory address of the first byte after the last occurrence of
    // `needle` in `self`, or the address of `self` if not found.
    function rfindPtr(uint selflen, uint selfptr, uint needlelen, uint needleptr) private pure returns (uint) {
        uint ptr;

        if (needlelen <= selflen) {
            if (needlelen <= 32) {
                bytes32 mask;
                if (needlelen > 0) {
                    mask = bytes32(~(2 ** (8 * (32 - needlelen)) - 1));
                }

                bytes32 needledata;
                assembly { needledata := and(mload(needleptr), mask) }

                ptr = selfptr + selflen - needlelen;
                bytes32 ptrdata;
                assembly { ptrdata := and(mload(ptr), mask) }

                while (ptrdata != needledata) {
                    if (ptr <= selfptr)
                        return selfptr;
                    ptr--;
                    assembly { ptrdata := and(mload(ptr), mask) }
                }
                return ptr + needlelen;
            } else {
                // For long needles, use hashing
                bytes32 hash;
                assembly { hash := keccak256(needleptr, needlelen) }
                ptr = selfptr + (selflen - needlelen);
                while (ptr >= selfptr) {
                    bytes32 testHash;
                    assembly { testHash := keccak256(ptr, needlelen) }
                    if (hash == testHash)
                        return ptr + needlelen;
                    ptr -= 1;
                }
            }
        }
        return selfptr;
    }

    /*
     * @dev Modifies `self` to contain everything from the first occurrence of
     *      `needle` to the end of the slice. `self` is set to the empty slice
     *      if `needle` is not found.
     * @param self The slice to search and modify.
     * @param needle The text to search for.
     * @return `self`.
     */
    function find(slice memory self, slice memory needle) internal pure returns (slice memory) {
        uint ptr = findPtr(self._len, self._ptr, needle._len, needle._ptr);
        self._len -= ptr - self._ptr;
        self._ptr = ptr;
        return self;
    }

    /*
     * @dev Modifies `self` to contain the part of the string from the start of
     *      `self` to the end of the first occurrence of `needle`. If `needle`
     *      is not found, `self` is set to the empty slice.
     * @param self The slice to search and modify.
     * @param needle The text to search for.
     * @return `self`.
     */
    function rfind(slice memory self, slice memory needle) internal pure returns (slice memory) {
        uint ptr = rfindPtr(self._len, self._ptr, needle._len, needle._ptr);
        self._len = ptr - self._ptr;
        return self;
    }

    /*
     * @dev Splits the slice, setting `self` to everything after the first
     *      occurrence of `needle`, and `token` to everything before it. If
     *      `needle` does not occur in `self`, `self` is set to the empty slice,
     *      and `token` is set to the entirety of `self`.
     * @param self The slice to split.
     * @param needle The text to search for in `self`.
     * @param token An output parameter to which the first token is written.
     * @return `token`.
     */
    function split(slice memory self, slice memory needle, slice memory token) internal pure returns (slice memory) {
        uint ptr = findPtr(self._len, self._ptr, needle._len, needle._ptr);
        token._ptr = self._ptr;
        token._len = ptr - self._ptr;
        if (ptr == self._ptr + self._len) {
            // Not found
            self._len = 0;
        } else {
            self._len -= token._len + needle._len;
            self._ptr = ptr + needle._len;
        }
        return token;
    }

    /*
     * @dev Splits the slice, setting `self` to everything after the first
     *      occurrence of `needle`, and returning everything before it. If
     *      `needle` does not occur in `self`, `self` is set to the empty slice,
     *      and the entirety of `self` is returned.
     * @param self The slice to split.
     * @param needle The text to search for in `self`.
     * @return The part of `self` up to the first occurrence of `delim`.
     */
    function split(slice memory self, slice memory needle) internal pure returns (slice memory token) {
        split(self, needle, token);
    }

    /*
     * @dev Splits the slice, setting `self` to everything before the last
     *      occurrence of `needle`, and `token` to everything after it. If
     *      `needle` does not occur in `self`, `self` is set to the empty slice,
     *      and `token` is set to the entirety of `self`.
     * @param self The slice to split.
     * @param needle The text to search for in `self`.
     * @param token An output parameter to which the first token is written.
     * @return `token`.
     */
    function rsplit(slice memory self, slice memory needle, slice memory token) internal pure returns (slice memory) {
        uint ptr = rfindPtr(self._len, self._ptr, needle._len, needle._ptr);
        token._ptr = ptr;
        token._len = self._len - (ptr - self._ptr);
        if (ptr == self._ptr) {
            // Not found
            self._len = 0;
        } else {
            self._len -= token._len + needle._len;
        }
        return token;
    }

    /*
     * @dev Splits the slice, setting `self` to everything before the last
     *      occurrence of `needle`, and returning everything after it. If
     *      `needle` does not occur in `self`, `self` is set to the empty slice,
     *      and the entirety of `self` is returned.
     * @param self The slice to split.
     * @param needle The text to search for in `self`.
     * @return The part of `self` after the last occurrence of `delim`.
     */
    function rsplit(slice memory self, slice memory needle) internal pure returns (slice memory token) {
        rsplit(self, needle, token);
    }

    /*
     * @dev Counts the number of nonoverlapping occurrences of `needle` in `self`.
     * @param self The slice to search.
     * @param needle The text to search for in `self`.
     * @return The number of occurrences of `needle` found in `self`.
     */
    function count(slice memory self, slice memory needle) internal pure returns (uint cnt) {
        uint ptr = findPtr(self._len, self._ptr, needle._len, needle._ptr) + needle._len;
        while (ptr <= self._ptr + self._len) {
            cnt++;
            ptr = findPtr(self._len - (ptr - self._ptr), ptr, needle._len, needle._ptr) + needle._len;
        }
    }

    /*
     * @dev Returns True if `self` contains `needle`.
     * @param self The slice to search.
     * @param needle The text to search for in `self`.
     * @return True if `needle` is found in `self`, false otherwise.
     */
    function contains(slice memory self, slice memory needle) internal pure returns (bool) {
        return rfindPtr(self._len, self._ptr, needle._len, needle._ptr) != self._ptr;
    }

    /*
     * @dev Returns a newly allocated string containing the concatenation of
     *      `self` and `other`.
     * @param self The first slice to concatenate.
     * @param other The second slice to concatenate.
     * @return The concatenation of the two strings.
     */
    function concat(slice memory self, slice memory other) internal pure returns (string memory) {
        string memory ret = new string(self._len + other._len);
        uint retptr;
        assembly { retptr := add(ret, 32) }
        memcpy(retptr, self._ptr, self._len);
        memcpy(retptr + self._len, other._ptr, other._len);
        return ret;
    }

    /*
     * @dev Joins an array of slices, using `self` as a delimiter, returning a
     *      newly allocated string.
     * @param self The delimiter to use.
     * @param parts A list of slices to join.
     * @return A newly allocated string containing all the slices in `parts`,
     *         joined with `self`.
     */
    function join(slice memory self, slice[] memory parts) internal pure returns (string memory) {
        if (parts.length == 0)
            return "";

        uint length = self._len * (parts.length - 1);
        for(uint i = 0; i < parts.length; i++)
            length += parts[i]._len;

        string memory ret = new string(length);
        uint retptr;
        assembly { retptr := add(ret, 32) }

        for(uint i = 0; i < parts.length; i++) {
            memcpy(retptr, parts[i]._ptr, parts[i]._len);
            retptr += parts[i]._len;
            if (i < parts.length - 1) {
                memcpy(retptr, self._ptr, self._len);
                retptr += self._len;
            }
        }

        return ret;
    }
}


contract NFA {
	

	

	string[] states = ['xehkbzck', 'zjbxzcze', 'imvkvydj', 'wmfyhunm', 'hstvavls', 'sgiknysg__emaakvmo', 'sgiknysg__kabtlhqz', 'faylsimy__emaakvmo', 'faylsimy__kabtlhqz', 'slnpjnvk', 'mwplmvlo', 'rsmzmhrx', 'gclnaket', 'vknlmpzy', 'dfrgtyed', 'jtozofio', 'meiurzal', 'ocbtoqtx', 'deuezwjo', 'vxtvgarh', 'mlimjdfb', 'zikmtwtq'];
	string[] tmpStates;
	string initialState = "xehkbzck";
	string[] finalStates = ['zikmtwtq', 'gclnaket'];
	string[] currentStates;
	string[] message;
	string epsilon;
	bool start;
	bool end;
	mapping(string => mapping(string => string[])) transitions;

	constructor() public {
		transitions['zjbxzcze']['Works_Manager?Concrete_casting_programme'] = ['imvkvydj'];
		transitions['xehkbzck'][''] = ['zjbxzcze'];
		transitions['wmfyhunm']['Batching_Plant?Concrete_order'] = ['hstvavls'];
		transitions['imvkvydj'][''] = ['wmfyhunm'];
		transitions['sgiknysg__emaakvmo']['Works_Manager?FPC_Certificate'] = ['sgiknysg__kabtlhqz'];
		transitions['sgiknysg__emaakvmo']['Building_Constructor?FPC_Certificate'] = ['faylsimy__emaakvmo'];
		transitions['sgiknysg__kabtlhqz']['Building_Constructor?FPC_Certificate'] = ['faylsimy__kabtlhqz'];
		transitions['faylsimy__emaakvmo']['Works_Manager?FPC_Certificate'] = ['faylsimy__kabtlhqz'];
		transitions['hstvavls'][''] = ['sgiknysg__emaakvmo'];
		transitions['mwplmvlo']['Batching_Plant?Refuse_supplier'] = ['rsmzmhrx'];
		transitions['rsmzmhrx'][''] = ['gclnaket'];
		transitions['slnpjnvk'][''] = ['vknlmpzy', 'mwplmvlo'];
		transitions['vknlmpzy']['Building_Constructor?Truck_mixer'] = ['dfrgtyed'];
		transitions['jtozofio']['Building_Constructor?Arrange_concrete_samplings'] = ['meiurzal'];
		transitions['dfrgtyed'][''] = ['jtozofio'];
		transitions['ocbtoqtx']['Laboratory?Concrete_specimens'] = ['deuezwjo'];
		transitions['meiurzal'][''] = ['ocbtoqtx'];
		transitions['vxtvgarh']['Works_Manager?Test_results'] = ['mlimjdfb'];
		transitions['deuezwjo'][''] = ['vxtvgarh'];
		transitions['mlimjdfb'][''] = ['zikmtwtq'];
		transitions['faylsimy__kabtlhqz'][''] = ['slnpjnvk'];
		
		delete tmpStates;
		tmpStates.push(initialState);
		currentStates = e_closure(tmpStates);
	}
	
	

	function strCompare(string memory stringA, string memory stringB) private returns (bool){
		return keccak256(abi.encodePacked(stringA)) == keccak256(abi.encodePacked(stringB));
	}
	
	
	function contains(string memory s, string[] memory states) private returns (bool){
		for (uint i = 0; i < states.length; i++) {
		    if (strCompare(s,states[i])) {
		        return true;
		    }
		}
		return false;
	}
	
	
	function checkInitialAndFinalStates(string[] memory states) private {
		start = false;
		end = false;
		for (uint i = 0; i < states.length; i++) {
		    if (strCompare(states[i],initialState)) {
		            start = true;
		        }
		        for (uint k = 0; k < finalStates.length; k++) {
		            if (strCompare(states[i],finalStates[k])) {
		                end = true;
		           }
		        }
		    }
	}
	
	
	function union(string[] memory arrayA, string[] memory arrayB) private returns (string[] memory){
		delete tmpStates;
		tmpStates = arrayA;
		for (uint i = 0; i < arrayB.length; i++) {
		    if(!contains(arrayB[i], tmpStates)) {
		        tmpStates.push(arrayB[i]);
		    }
		}
		return tmpStates;
	}
	
	
	function e_closure(string[] memory states) private returns (string[] memory){
		delete tmpStates;
		tmpStates = states;
		bool found = (tmpStates.length > 0);
		while (found) {
		    found = false;
		    for (uint i = 0; i < tmpStates.length; i++) {
		        for (uint j = 0; j < transitions[tmpStates[i]][epsilon].length; j++) {
		            if (!contains(transitions[tmpStates[i]][epsilon][j], tmpStates)) {
		                tmpStates.push(transitions[tmpStates[i]][epsilon][j]);
		                found = true;
		            }
		        }
		    }
		}
		checkInitialAndFinalStates(tmpStates);
		return tmpStates;
	}
	
	
	function getStates() public view returns (string[] memory){
		return states;
	}
	
	
	function getCurrentStates() public view returns (string[] memory){
		return currentStates;
	}
	
	
	function getFinalStates() public view returns (string[] memory){
		return finalStates;
	}
	
	
	function isFinal() public view returns (bool){
		return end;
	}
	
	
	function isInitial() public view returns (bool){
		return start;
	}
	
	
	function getMessage() public view returns (string[] memory){
		return message;
	}
	
	
	function transitionFrom(string memory state, string memory label) public returns (string[] memory){
		return transitions[state][label];
	}
	
	
	function transition(string memory label) public {
		delete tmpStates;
		for (uint i = 0; i < currentStates.length; i++) {
		    string[] memory s = transitionFrom(currentStates[i],label);
		    tmpStates = union(tmpStates, s);
		}
		require(tmpStates.length != 0);
		message.push(label);
		currentStates = e_closure(tmpStates);
	}
	
	
	function checkEnabledTransitions(string memory symbol) public returns (bool){
		for (uint i = 0; i < currentStates.length; i++) {
		    string[] memory s_reached = transitionFrom(currentStates[i], symbol);
		    if (s_reached.length > 0) return true;
		    //reached = union(reached, s_reached); 
		}
		return false;
	}
	
	
}  


contract Enforcer {
	using strings for *;

	event outputEvent(string debug, string messageOut);

	NFA nfa;
	string[] actors;
	string[] messages;
	string[] tmpStates;
	mapping(string => mapping(string => uint)) buffer;

	constructor(address nfaAddress) public {
		nfa = NFA(nfaAddress);
	}
	
	

	function strCompare(string memory stringA, string memory stringB) internal pure returns (bool){
		return keccak256(abi.encodePacked(stringA)) == keccak256(abi.encodePacked(stringB));
	}
	
	
	function arrContains(string[] memory states, string memory s) internal pure returns (bool){
		for (uint i = 0; i < states.length; i++) {
		    if (strCompare(s,states[i])) {
		        return true;
		    }
		}
		return false;
	}
	
	
	function contains(string memory what, string memory where) internal pure returns (bool){
		strings.slice memory where = where.toSlice();
		strings.slice memory what = what.toSlice();
		return where.contains(what);
	}
	
	
	function split(string memory sequence, string memory del) private returns (string[] memory){
		strings.slice memory s = sequence.toSlice();
		strings.slice memory delim = del.toSlice();
		string[] memory parts = new string[](s.count(delim) + 1);
		for(uint i = 0; i < parts.length; i++) {
		    parts[i] = s.split(delim).toString();
		}
		return parts;
	}
	
	
	function union(string[] memory arrayA, string[] memory arrayB) private returns (string[] memory){
		delete tmpStates;
		for (uint i = 0; i < arrayB.length; i++) {
		    tmpStates.push(arrayB[i]);
		}
		for (uint i = 0; i < arrayA.length; i++) {
		    if(!arrContains(tmpStates, arrayA[i])) {
		        tmpStates.push(arrayA[i]);
		    }
		}
		return tmpStates;
	}
	
	
	function buffer_add(string memory actor, string memory message) private {
		uint counter = buffer[actor][message];
		counter += 1;
		if (!arrContains(actors,actor)) {
		    actors.push(actor);
		}
		if(!arrContains(messages,message)) {
		    messages.push(message);
		}
		buffer[actor][message] = counter;
	}
	
	
	function buffer_remove(string memory actor, string memory message) private {
		uint counter = buffer[actor][message];
		require(counter > 0, string(abi.encodePacked("No message ", message, " to remove for actor ", actor)));
		counter -= 1;
		buffer[actor][message] = counter;
	}
	
	
	function condition_rule_send(string memory message) private returns (bool){
		return contains("!", message);
	}
	
	
	function condition_rule_receive_now(string memory message) private returns (bool){
		return contains("?", message) && nfa.checkEnabledTransitions(message);
	}
	
	
	function condition_rule_receive_delayed(string memory message) private returns (bool){
		return contains("?", message);
	}
	
	
	function condition_rule_receive_buffered() private returns (string memory){
		delete tmpStates;
		for (uint i = 0; i < actors.length; i++) {
		    for (uint j = 0; j < messages.length; j++) {
		        if (buffer[actors[i]][messages[j]] > 0) {
		            string memory message = string(abi.encodePacked(actors[i],"?",messages[j]));
		            string[] memory currentStates = nfa.getCurrentStates();
		            for (uint s = 0; s < currentStates.length; s++) {
		                tmpStates = nfa.transitionFrom(currentStates[s], message);
		                if (tmpStates.length > 0) {
		                    return message;
		                }
		            }
		        }
		    }
		}
		return "None";
	}
	
	
	function rule_send(string memory message) private returns (string memory){
		return message;
	}
	
	
	function rule_receive_now(string memory message) private returns (string memory){
		nfa.transition(message);
		return message;
	}
	
	
	function rule_receive_delayed(string memory actor, string memory message) private returns (string memory){
		buffer_add(actor, message);
		return "";
	}
	
	
	function rule_receive_buffered(string memory actor, string memory message) private returns (string memory){
		nfa.transition(string(abi.encodePacked(actor,"?",message)));
		buffer_remove(actor, message);
		return string(abi.encodePacked(actor,"?",message));
	}
	
	
	function getActors() public view returns (string[] memory){
		return actors;
	}
	
	
	function getMessages() public view returns (string[] memory){
		return messages;
	}
	
	
	function get_buffer_item(string memory actor, string memory message) public view returns (uint){
		return buffer[actor][message];
	}
	
	
	function process_input(string memory event_input) public returns (string memory){
		string memory out;
		string memory debug;
		if (condition_rule_send(event_input)) {
		    debug = string(abi.encodePacked("(* Condition rule receive send: ", event_input, " *)"));
		    out = rule_send(event_input);
		} else if (condition_rule_receive_now(event_input)) {
		    string memory actor = split(event_input, "?")[0];
		    string memory message = split(event_input, "?")[1];
		    debug = string(abi.encodePacked("(* Condition rule receive now: ", event_input, " *)"));
		    out = rule_receive_now(event_input);
		    } else if (condition_rule_receive_delayed(event_input)) {
		        string memory actor = split(event_input, "?")[0];
		        string memory message = split(event_input, "?")[1];
		        debug = string(abi.encodePacked("(* Condition rule receive delayed: ", event_input, " *)"));
		        out = rule_receive_delayed(actor, message);
		    } else {
		        debug = "No matching condition";
		        out = "None";
		    }
		emit outputEvent(debug, out);
		return out;
	}
	
	
	function process_check() public returns (string memory){
		string memory out = "";
		string memory debug;
		string memory message = condition_rule_receive_buffered();
		if(!strCompare(message,"None")) {
		    string memory actor = split(message, "?")[0];
		    string memory action = split(message, "?")[1];
		    debug = string(abi.encodePacked("(* Condition rule receive buffered: ", message, " *)"));
		    out = rule_receive_buffered(actor, action);            
		} else {
		            out = "None";
		            debug = "(* No usable message found in buffer for current states. *)";
		        }
		emit outputEvent(debug, out);
		return out;
	}
	
	
}  


