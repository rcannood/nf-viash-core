package dataintuitive.plugin

import nextflow.Session
import spock.lang.Specification

/**
 * Implements a basic factory test
 *
 */
class NfViashObserverTest extends Specification {

    def 'should create the observer instance' () {
        given:
        def factory = new NfViashFactory()
        when:
        def result = factory.create(Mock(Session))
        then:
        result.size() == 1
        result.first() instanceof NfViashObserver
    }

}
