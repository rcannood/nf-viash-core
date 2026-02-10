/*
 * Copyright 2025, Seqera Labs
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

package io.viash.viash_core

import nextflow.Session
import nextflow.plugin.extension.Function
import nextflow.plugin.extension.PluginExtensionPoint

import java.nio.file.Path

import io.viash.viash_core.config.ConfigUtils
import io.viash.viash_core.config.DirectiveUtils
import io.viash.viash_core.help.HelpUtils
import io.viash.viash_core.help.TextUtils
import io.viash.viash_core.io.SerializationUtils
import io.viash.viash_core.state.StateUtils
import io.viash.viash_core.util.CollectionUtils
import io.viash.viash_core.util.PathUtils

/**
 * ViashCore plugin extension point.
 * Exposes pure utility functions for use in Nextflow scripts.
 */
class ViashCoreExtension extends PluginExtensionPoint {

    @Override
    protected void init(Session session) {
    }

    // ---- Collection utilities (io.viash.viash_core.util) ----

    @Function
    Object iterateMap(Object obj, Closure fun) {
        CollectionUtils.iterateMap(obj, fun)
    }

    @Function
    Object deepClone(Object x) {
        CollectionUtils.deepClone(x)
    }

    @Function
    Map mergeMap(Map lhs, Map rhs) {
        CollectionUtils.mergeMap(lhs, rhs)
    }

    @Function
    List collectFiles(Object obj) {
        CollectionUtils.collectFiles(obj)
    }

    @Function
    List collectInputOutputPaths(Object obj, String prefix) {
        CollectionUtils.collectInputOutputPaths(obj, prefix)
    }

    // ---- Text utilities (io.viash.viash_core.help) ----

    @Function
    List<String> paragraphWrap(String str, int maxLength) {
        TextUtils.paragraphWrap(str, maxLength)
    }

    // ---- Serialization utilities (io.viash.viash_core.io) ----

    @Function
    Object readJsonBlob(String str) {
        SerializationUtils.readJsonBlob(str)
    }

    @Function
    Object readYamlBlob(String str) {
        SerializationUtils.readYamlBlob(str)
    }

    @Function
    Object readTaggedYaml(Path path) {
        SerializationUtils.readTaggedYaml(path)
    }

    @Function
    String toJsonBlob(Object data) {
        SerializationUtils.toJsonBlob(data)
    }

    @Function
    String toYamlBlob(Object data) {
        SerializationUtils.toYamlBlob(data)
    }

    @Function
    String toTaggedYamlBlob(Object data) {
        SerializationUtils.toTaggedYamlBlob(data)
    }

    @Function
    String toRelativeTaggedYamlBlob(Object data, Path relativizer) {
        SerializationUtils.toRelativeTaggedYamlBlob(data, relativizer)
    }

    @Function
    void writeJson(Object data, File file) {
        SerializationUtils.writeJson(data, file)
    }

    @Function
    void writeYaml(Object data, File file) {
        SerializationUtils.writeYaml(data, file)
    }

    // ---- Config utilities (io.viash.viash_core.config) ----

    @Function
    Map processConfig(Map config) {
        ConfigUtils.processConfig(config)
    }

    @Function
    Map processArgument(Map arg) {
        ConfigUtils.processArgument(arg)
    }

    @Function
    Map processAuto(Map auto) {
        ConfigUtils.processAuto(auto)
    }

    @Function
    void assertMapKeys(Map map, List expectedKeys, List requiredKeys, String mapName) {
        ConfigUtils.assertMapKeys(map, expectedKeys, requiredKeys, mapName)
    }

    // ---- Help utilities (io.viash.viash_core.help) ----

    @Function
    String generateArgumentHelp(Map param) {
        HelpUtils.generateArgumentHelp(param)
    }

    @Function
    String generateHelp(Map config) {
        HelpUtils.generateHelp(config)
    }

    // ---- Path utilities (io.viash.viash_core.util) ----

    @Function
    boolean stringIsAbsolutePath(String path) {
        PathUtils.stringIsAbsolutePath(path)
    }

    @Function
    String getChild(String parent, String child) {
        PathUtils.getChild(parent, child)
    }

    @Function
    Path getRootDir(Path resourcesDir) {
        PathUtils.getRootDir(resourcesDir)
    }

    // ---- Directive utilities (io.viash.viash_core.config) ----

    @Function
    Map processDirectives(Map drctv) {
        DirectiveUtils.processDirectives(drctv)
    }

    @Function
    Map processDirectivesWithOverride(Map drctv, String containerRegistryOverride) {
        DirectiveUtils.processDirectives(drctv, containerRegistryOverride)
    }

    // ---- State utilities (io.viash.viash_core.state) ----

    @Function
    void checkUniqueIds(List parameterSets) {
        StateUtils.checkUniqueIds(parameterSets)
    }

    @Function
    Map splitParams(Map parValues, Map config) {
        StateUtils.splitParams(parValues, config)
    }

    @Function
    String paramListGuessFormat(Object paramList) {
        StateUtils.paramListGuessFormat(paramList)
    }

    @Function
    Object processFromState(Object fromState, String key_, Map config_) {
        StateUtils.processFromState(fromState, key_, config_)
    }

    @Function
    Object processToState(Object toState, String key_, Map config_) {
        StateUtils.processToState(toState, key_, config_)
    }
}
