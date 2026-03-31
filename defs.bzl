"""Custom rules and aspects for C++ shared library dependency management."""

load("@rules_cc//cc/common:cc_common.bzl", "cc_common")
load("@rules_cc//cc/common:cc_shared_library_info.bzl", "CcSharedLibraryInfo")

## PROVIDER

CollectedCcSharedLibraryInfo = provider(
    "Collection of cc_shared_library providers.",
    fields = [
        "cc_shared_library_info",
    ],
)

## ASPECT

def _collect_transitive_dynamic_deps_aspect_impl(target, ctx):
    direct_cc_shared_library_infos = [
        target[CcSharedLibraryInfo],
    ] if CcSharedLibraryInfo in target else []
    transitive_cc_shared_library_infos = [
        dep[CollectedCcSharedLibraryInfo].cc_shared_library_info
        for dep in ctx.rule.attr.dynamic_deps
        if CollectedCcSharedLibraryInfo in dep
    ]
    return [
        CollectedCcSharedLibraryInfo(
            cc_shared_library_info = depset(
                direct = direct_cc_shared_library_infos,
                transitive = transitive_cc_shared_library_infos,
            ),
        ),
    ]

collect_transitive_dynamic_deps_aspect = aspect(
    implementation = _collect_transitive_dynamic_deps_aspect_impl,
    attr_aspects = ["dynamic_deps"],
    provides = [CollectedCcSharedLibraryInfo],
)

## RULE

def _collect_transitive_dynamic_deps_impl(ctx):
    transitive_cc_shared_library_infos = [
        dep[CollectedCcSharedLibraryInfo].cc_shared_library_info
        for dep in ctx.attr.dynamic_deps
        if CollectedCcSharedLibraryInfo in dep
    ]
    
    # 1. Flatten the list of depsets into a single depset and convert to list for iteration
    all_infos = depset(transitive = transitive_cc_shared_library_infos).to_list()
    
    # 2. Collect the 'libraries' depset from each CcSharedLibraryInfo's linker_input
    transitive_libs = []
    for info in all_infos:
        # Check if it has linker_input and it's not None
        if hasattr(info, "linker_input") and info.linker_input:
            transitive_libs += info.linker_input.libraries
            
    return [
        CcSharedLibraryInfo(
            dynamic_deps = depset(transitive = transitive_cc_shared_library_infos),
            exports = [],
            linker_input = cc_common.create_linker_input(
                owner = ctx.label,
                libraries = depset(direct = transitive_libs),
            ),
            link_once_static_libs = [],
        ),
    ]

collect_transitive_dynamic_deps = rule(
    implementation = _collect_transitive_dynamic_deps_impl,
    attrs = {
        "dynamic_deps": attr.label_list(
            aspects = [
                collect_transitive_dynamic_deps_aspect,
            ],
            providers = [CcSharedLibraryInfo],
            allow_files = False,
        ),
    },
    provides = [CcSharedLibraryInfo],
)
