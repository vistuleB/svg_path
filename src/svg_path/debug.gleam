//// Temporary debug constants.
////
//// This module is intentionally allowed to churn during exploratory geometry
//// work. Release cleanup should verify that no main-package module imports it.

/// Package-title source/refined-source closeup.
///
/// The tuple is #(source_subpath_index, highlighted_offset_segment_index).
pub const package_title_refined_source_probe = #(6, 48)

/// Package-title source/refined-source focus.
///
/// The tuple is #(join_free_index, source_segment_index, refined_piece_index).
pub const package_title_refined_source_focus = #(10, 1, 2)

/// Package-title arrangement edge focus.
pub const package_title_arrangement_edge_focus = 68
