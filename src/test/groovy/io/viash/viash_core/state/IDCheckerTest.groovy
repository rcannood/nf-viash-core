package io.viash.viash_core.state

import spock.lang.Specification

class IDCheckerTest extends Specification {

    def 'should observe new items successfully' () {
        given:
        def checker = new IDChecker()
        
        expect:
        checker.observe("a") == true
        checker.observe("b") == true
        checker.observe("c") == true
    }

    def 'should reject duplicate items' () {
        given:
        def checker = new IDChecker()
        checker.observe("a")
        
        expect:
        checker.observe("a") == false
    }

    def 'should check contains correctly' () {
        given:
        def checker = new IDChecker()
        checker.observe("a")
        
        expect:
        checker.contains("a") == true
        checker.contains("b") == false
    }

    def 'should return clone of items' () {
        given:
        def checker = new IDChecker()
        checker.observe("x")
        checker.observe("y")
        
        when:
        def items = checker.getItems()
        
        then:
        items.size() == 2
        items.contains("x")
        items.contains("y")
    }

    def 'should be thread-safe' () {
        given:
        def checker = new IDChecker()
        def results = Collections.synchronizedList([])
        
        when:
        def threads = (0..99).collect { i ->
            Thread.start {
                results.add(checker.observe("item_${i}"))
            }
        }
        threads.each { it.join() }
        
        then:
        results.count { it == true } == 100
        checker.getItems().size() == 100
    }
}
