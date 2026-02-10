package io.viash.viash_core.help

import spock.lang.Specification

class TextUtilsTest extends Specification {

    def 'paragraphWrap should wrap long lines' () {
        when:
        def result = TextUtils.paragraphWrap("this is a fairly long line that should be wrapped at some point", 30)
        
        then:
        result.every { it.length() <= 30 }
        result.size() > 1
    }

    def 'paragraphWrap should preserve short lines' () {
        when:
        def result = TextUtils.paragraphWrap("short line", 80)
        
        then:
        result == ["short line"]
    }

    def 'paragraphWrap should preserve paragraph breaks' () {
        when:
        def result = TextUtils.paragraphWrap("line one\nline two", 80)
        
        then:
        result == ["line one", "line two"]
    }

    def 'paragraphWrap should handle empty string' () {
        when:
        def result = TextUtils.paragraphWrap("", 80)
        
        then:
        result == [""]
    }
}
