# SSUI parity

Owner, 2026-11-14: "fully recreate all the SSUI components we have in CodelesslySDK as part of the default set.
A lot of the defaults you're using are made up and not the professional SSUI designs we have in our component
library."

The source is `Researchy/soft_saas_ui/src/components` (164 components) with `SSUI_PATTERNS.md`. A component is
**here** when the SDK draws it from SSUI's own values: as a control the tree draws (a render object) or as a
document in `components/` written by `tool/generate.py`. Each new one is built from the source file's numbers
(sizes, radii, paddings, type, colors by token), rendered, and looked at beside the source.

**Here: 93. Still to rebuild: 71.**

## Here

| SSUI component | Design-system document | Control the tree draws |
|---|---|---|
| ActionListItem | ActionListItem |  |
| AddButton | AddButton |  |
| AgentChip | AgentChip |  |
| AuthPromptBanner | AuthPromptBanner |  |
| Avatar | Avatar |  |
| BackButton | BackButton |  |
| Badge | Badge |  |
| Banner | Banner |  |
| BatchProgressBar | BatchProgressBar |  |
| Breadcrumb | Breadcrumb |  |
| Button | Button | buttons (filled, outlined, text, elevated) |
| CardActions | CardActions |  |
| Carousel |  | pageView |
| Checkbox | Checkbox | checkbox |
| Chip | Chip | chip family |
| ChipTabs | ChipTabs |  |
| CloudSyncIndicator | CloudSyncIndicator |  |
| CodeBlock | CodeBlock |  |
| ConnectionStatus | ConnectionStatus |  |
| CopyButton | CopyButton |  |
| CountBadge | CountBadge |  |
| DatePicker |  | datePicker |
| Dialog | Dialog | confirm action / modal |
| DiffStatsBadge | DiffStatsBadge |  |
| DocumentItem | DocumentItem |  |
| DownloadButton | DownloadButton |  |
| Dropdown |  | dropdown |
| EmptyState | EmptyState |  |
| ErrorBar | ErrorBar |  |
| FeatureBulletItem | FeatureBulletItem |  |
| Field | Field |  |
| FileListItem | FileListItem |  |
| FileMetadataCard | FileMetadataCard |  |
| FilterLegend | FilterLegend |  |
| FloatingActionButton |  | floatingActionButton |
| Hyperlink | Hyperlink |  |
| IconBox | IconBox |  |
| IconButton | IconButton | iconButton |
| InlineStat | InlineStat |  |
| LoadingSpinner |  | activityIndicator |
| LoadMore | LoadMore |  |
| MenuButton | MenuButton |  |
| MetaInfo | MetaInfo |  |
| NotificationBadge | NotificationBadge |  |
| OnboardingBanner | OnboardingBanner |  |
| OptionIcon | OptionIcon |  |
| PageControl | PageControl |  |
| Pagination |  | pagination |
| Panel | Panel |  |
| PersonChip | PersonChip |  |
| ProgressIndicator | ProgressBar | progressBar |
| PromptBanner | PromptBanner |  |
| ProviderCard | ProviderCard |  |
| ProviderIcon | ProviderIcon |  |
| ProviderPill | ProviderPill |  |
| PulsingDots | PulsingDots |  |
| RadialProgress | RadialProgress |  |
| RadioButton | Radio | radio |
| ResourceChip | ResourceChip |  |
| RunningIndicator | RunningIndicator |  |
| RunRecordRow | RunRecordRow |  |
| SearchBar | SearchBar |  |
| SectionCard | SectionCard |  |
| SegmentedControl | SegmentedControl | segmentedButton |
| Select | Select | dropdown |
| SelectableListRow | SelectableListRow |  |
| Skeleton | Skeleton |  |
| Slider | Slider | slider |
| SplitButton | SplitButton |  |
| StackedProgressBar | StackedProgressBar |  |
| StatsRow | StatTile (dashboard density), InlineStat (compact) |  |
| StatusBadge | StatusBadge |  |
| StatusDot | StatusDot |  |
| StatusIndicator | StatusIndicator |  |
| StepIndicator | StepIndicator |  |
| Stepper | Stepper |  |
| Switch | Switch | switch |
| Table |  | tableView |
| TabToggle | TabToggle |  |
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
| Tooltip | Tooltip | tooltip behavior |
| TrialBanner | TrialBanner |  |
| UpgradeButton | UpgradeButton |  |
| WindowToolbar | WindowToolbar |  |

Also here with no source file of the same name: Card, ListRow, SectionHeader, Tabs.

## Still to rebuild

In the order planned: what generated UI reaches for first, then the application chrome.

### Text and small content (1)

CodePreview

### Cards and rows (6)

FolderCard, ResourceCard, RunHistoryList, StatusCardList, StatsCarousel, ModelAvatarStack

### Inputs (19)

FullWidthSearchInput, HeaderSearchInput, Combobox, NumberInput, NumberPresetInput, ColorInput, AuthInput, ExtensionChipsInput, FileUploader, ImageUpload, IconSelect, IconSegmentedControl, DropdownMultiselect, MultiSelectDropdown, HierarchicalPicker, RichTextField, RichTextToolbar, PromptInput, PromptInputWithBanner

### Navigation and chrome (17)

BrowserTabs, TabBarWithBadges, TabOverflowScroll, SplitPaneTabs, Sidebar, SidebarTogglePattern, NavigationMenu, CompactAppBar, SectionToolbar, PaneToolbar, Toolbar, SectionCategoryHeaderFull, StatusCategoryHeader, CollapsibleSection, ScrollToBottomFAB, CanvasShell, ResizableRow

### Menus and overlays (14)

ContextMenu, AddContextMenu, FileTreeContextMenu, MenuPopover, SortMenu, UserMenu, ModelSelectMenu, ProjectSelector, WorkspaceSwitcher, CommandPalette, NotePopover, SlidingPanel, ViewerDialog, VariableContractHover

### Data and specialized (14)

Tree, FileTree, DiffViewer, Terminal, HistoryTimeline, DateTimelineAxis, ImageGallery, NestedTaskLedger, ReorderableList, ReorderGhost, SuggestionReviewItem, CompactSuggestionReviewItem, SuggestionActionObject, VariableContractList
