# SSUI parity

Owner, 2026-11-14: "fully recreate all the SSUI components we have in CodelesslySDK as part of the default set.
A lot of the defaults you're using are made up and not the professional SSUI designs we have in our component
library."

The source is `Researchy/soft_saas_ui/src/components` (164 components) with `SSUI_PATTERNS.md`. A component is
**here** when the SDK draws it from SSUI's own values: as a control the tree draws (a render object) or as a
document in `components/` written by `tool/generate.py`. Each new one is built from the source file's numbers
(sizes, radii, paddings, type, colors by token), rendered, and looked at beside the source.

**Here: 164. Still to rebuild: 0.**

## Here

| SSUI component | Design-system document | Control the tree draws |
|---|---|---|
| ActionListItem | ActionListItem |  |
| AddButton | AddButton |  |
| AddContextMenu | AddContextMenu |  |
| AgentChip | AgentChip |  |
| AuthInput | AuthInput |  |
| AuthPromptBanner | AuthPromptBanner |  |
| Avatar | Avatar |  |
| BackButton | BackButton |  |
| Badge | Badge |  |
| Banner | Banner |  |
| BatchProgressBar | BatchProgressBar |  |
| Breadcrumb | Breadcrumb |  |
| BrowserTabs | BrowserTabs |  |
| Button | Button | buttons (filled, outlined, text, elevated) |
| CanvasShell | CanvasShell |  |
| CardActions | CardActions |  |
| Carousel |  | pageView |
| Checkbox | Checkbox | checkbox |
| Chip | Chip | chip family |
| ChipTabs | ChipTabs |  |
| CloudSyncIndicator | CloudSyncIndicator |  |
| CodeBlock | CodeBlock |  |
| CodePreview | CodePreview |  |
| CollapsibleSection | CollapsibleSection |  |
| ColorInput | ColorInput |  |
| Combobox | Combobox |  |
| CommandPalette | CommandPalette |  |
| CompactAppBar | CompactAppBar |  |
| CompactSuggestionReviewItem | CompactSuggestionReviewItem |  |
| ConnectionStatus | ConnectionStatus |  |
| ContextMenu | ContextMenu |  |
| CopyButton | CopyButton |  |
| CountBadge | CountBadge |  |
| DatePicker |  | datePicker |
| DateTimelineAxis | DateTimelineAxis |  |
| Dialog | Dialog | confirm action / modal |
| DiffStatsBadge | DiffStatsBadge |  |
| DiffViewer | DiffViewer |  |
| DocumentItem | DocumentItem |  |
| DownloadButton | DownloadButton |  |
| Dropdown |  | dropdown |
| DropdownMultiselect | DropdownMultiselect |  |
| EmptyState | EmptyState |  |
| ErrorBar | ErrorBar |  |
| ExtensionChipsInput | ExtensionChipsInput |  |
| FeatureBulletItem | FeatureBulletItem |  |
| Field | Field |  |
| FileListItem | FileListItem |  |
| FileMetadataCard | FileMetadataCard |  |
| FileTree | FileTree |  |
| FileTreeContextMenu | FileTreeContextMenu |  |
| FileUploader | FileUploader |  |
| FilterLegend | FilterLegend |  |
| FloatingActionButton |  | floatingActionButton |
| FolderCard | FolderCard |  |
| FullWidthSearchInput | FullWidthSearchInput |  |
| HeaderSearchInput | HeaderSearchInput |  |
| HierarchicalPicker | HierarchicalPicker |  |
| HistoryTimeline | HistoryTimeline |  |
| Hyperlink | Hyperlink |  |
| IconBox | IconBox |  |
| IconButton | IconButton | iconButton |
| IconSegmentedControl | IconSegmentedControl |  |
| IconSelect | IconSelect |  |
| ImageGallery | ImageGallery |  |
| ImageUpload | ImageUpload |  |
| InlineStat | InlineStat |  |
| LoadingSpinner |  | activityIndicator |
| LoadMore | LoadMore |  |
| MenuButton | MenuButton |  |
| MenuPopover | MenuPopover (with MenuItem) |  |
| MetaInfo | MetaInfo |  |
| ModelAvatarStack | ModelAvatarStack |  |
| ModelSelectMenu | ModelSelectMenu |  |
| MultiSelectDropdown | MultiSelectDropdown |  |
| NavigationMenu | NavigationMenu |  |
| NestedTaskLedger | NestedTaskLedger |  |
| NotePopover | NotePopover |  |
| NotificationBadge | NotificationBadge |  |
| NumberInput | NumberInput |  |
| NumberPresetInput | NumberPresetInput |  |
| OnboardingBanner | OnboardingBanner |  |
| OptionIcon | OptionIcon |  |
| PageControl | PageControl |  |
| Pagination |  | pagination |
| Panel | Panel |  |
| PaneToolbar | PaneToolbar |  |
| PersonChip | PersonChip |  |
| ProgressIndicator | ProgressBar | progressBar |
| ProjectSelector | ProjectSelector |  |
| PromptBanner | PromptBanner |  |
| PromptInput | PromptInput |  |
| PromptInputWithBanner | PromptInputWithBanner |  |
| ProviderCard | ProviderCard |  |
| ProviderIcon | ProviderIcon |  |
| ProviderPill | ProviderPill |  |
| PulsingDots | PulsingDots |  |
| RadialProgress | RadialProgress |  |
| RadioButton | Radio | radio |
| ReorderableList | ReorderableList |  |
| ReorderGhost | ReorderGhost |  |
| ResizableRow | ResizableRow |  |
| ResourceCard | ResourceCard |  |
| ResourceChip | ResourceChip |  |
| RichTextField | RichTextField |  |
| RichTextToolbar | RichTextToolbar |  |
| RunHistoryList | RunHistoryList |  |
| RunningIndicator | RunningIndicator |  |
| RunRecordRow | RunRecordRow |  |
| ScrollToBottomFAB | ScrollToBottomFAB |  |
| SearchBar | SearchBar |  |
| SectionCard | SectionCard |  |
| SectionCategoryHeaderFull | SectionCategoryHeaderFull |  |
| SectionToolbar | SectionToolbar |  |
| SegmentedControl | SegmentedControl | segmentedButton |
| Select | Select | dropdown |
| SelectableListRow | SelectableListRow |  |
| Sidebar | Sidebar |  |
| SidebarTogglePattern | SidebarTogglePattern |  |
| Skeleton | Skeleton |  |
| Slider | Slider | slider |
| SlidingPanel | SlidingPanel |  |
| SortMenu | SortMenu |  |
| SplitButton | SplitButton |  |
| SplitPaneTabs | SplitPaneTabs |  |
| StackedProgressBar | StackedProgressBar |  |
| StatsCarousel | StatsCarousel |  |
| StatsRow | StatTile (dashboard density), InlineStat (compact) |  |
| StatusBadge | StatusBadge |  |
| StatusCardList | StatusCardList (with StatusCard) |  |
| StatusCategoryHeader | StatusCategoryHeader |  |
| StatusDot | StatusDot |  |
| StatusIndicator | StatusIndicator |  |
| StepIndicator | StepIndicator |  |
| Stepper | Stepper |  |
| SuggestionActionObject | SuggestionActionObject |  |
| SuggestionReviewItem | SuggestionReviewItem |  |
| Switch | Switch | switch |
| TabBarWithBadges | TabBarWithBadges |  |
| Table |  | tableView |
| TabOverflowScroll | TabOverflowScroll |  |
| TabToggle | TabToggle |  |
| Terminal | Terminal |  |
| TextArea | TextArea | textField (maxLines) |
| TextExpandable | TextExpandable |  |
| TextField | TextInput | textField |
| TextInput | TextInput | textField |
| TextInputLabel | TextInputLabel |  |
| TextItem | TextItem |  |
| ThemeToggle | ThemeToggle |  |
| TimePicker |  | timePicker |
| Toast |  | showToast action |
| ToggleRow | ToggleRow |  |
| Toolbar | Toolbar |  |
| Tooltip | Tooltip | tooltip behavior |
| Tree | Tree |  |
| TrialBanner | TrialBanner |  |
| UpgradeButton | UpgradeButton |  |
| UserMenu | UserMenu |  |
| VariableContractHover | VariableContractHover |  |
| VariableContractList | VariableContractList |  |
| ViewerDialog | ViewerDialog |  |
| WindowToolbar | WindowToolbar |  |
| WorkspaceSwitcher | WorkspaceSwitcher |  |

Also here with no source file of the same name: Card, ListRow, SectionHeader, Tabs.

## Where a rebuilt component is less than its source

All 164 are here. These are not one-to-one, and say so in their own doc lines:

- **Menus and pickers open in place.** Combobox, DropdownMultiselect, IconSelect, NumberPresetInput, ProjectSelector and
  NotePopover open their panel under the trigger, in the layout, where the source floats it over the page. MenuPopover,
  ContextMenu, SortMenu, UserMenu, WorkspaceSwitcher, ModelSelectMenu, CommandPalette and the two small context menus
  are the surfaces only: the host shows them (a modal action, a stack).
- **Rows come from lists of text.** A component's props are text, numbers, booleans and lists of text, so a component
  that takes a list of objects in the source takes parallel lists here (labels, icons, badges, depths), or is split into
  a container and a row component (StatusCardList and StatusCard, RunHistoryList and RunRecordRow, MenuPopover and
  MenuItem). BatchProgressBar is one operation; stack one per operation.
- **Trees do not fold.** Tree, FileTree, HierarchicalPicker and NestedTaskLedger show every row at its depth; their
  chevrons mark a row that holds others and do not collapse it.
- **Parts left out.** FolderCard has no settings rows, menu, triggers or git line. TrialBanner is the compact bar, not
  the prominent card. ImageGallery is the grid, not the full-screen viewer. Toolbar is one generic bar of tools, not the
  four editor presets. CollapsibleSection asks its host for the rest of its items rather than hiding rows itself.
  SuggestionReviewItem has no evidence or details section. VariableContractHover and VariableContractList show no JSON
  schema.
- **Dragging.** ResizableRow takes its first pane's width from the call and has no drag of its own. DateTimelineAxis
  spaces its ticks evenly, not by date, and does not pan. TabOverflowScroll scrolls by hand; its chevron is a hint, not
  a button. ReorderableList does reorder by its grips.
- **Monospace** is asked for by name ("monospace"); the render tool has no such font and draws those texts in the sans
  face, with a `font_fallback` warning. An app that ships a monospace font gets it.
