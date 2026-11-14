# SSUI parity

Owner, 2026-11-14: "fully recreate all the SSUI components we have in CodelesslySDK as part of the default set.
A lot of the defaults you're using are made up and not the professional SSUI designs we have in our component
library."

The source is `Researchy/soft_saas_ui/src/components` (164 components) with `SSUI_PATTERNS.md`. A component is
**here** when the SDK draws it from SSUI's own values: as a control the tree draws (a render object) or as a
document in `components/` written by `tool/generate.py`. Each new one is built from the source file's numbers
(sizes, radii, paddings, type, colors by token), rendered, and looked at beside the source.

**Here: 121. Still to rebuild: 43.**

## Here

| SSUI component | Design-system document | Control the tree draws |
|---|---|---|
| ActionListItem | ActionListItem |  |
| AddButton | AddButton |  |
| AgentChip | AgentChip |  |
| AuthInput | AuthInput |  |
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
| ColorInput | ColorInput |  |
| CommandPalette | CommandPalette |  |
| CompactAppBar | CompactAppBar |  |
| ConnectionStatus | ConnectionStatus |  |
| ContextMenu | ContextMenu |  |
| CopyButton | CopyButton |  |
| CountBadge | CountBadge |  |
| DatePicker |  | datePicker |
| Dialog | Dialog | confirm action / modal |
| DiffStatsBadge | DiffStatsBadge |  |
| DiffViewer | DiffViewer |  |
| DocumentItem | DocumentItem |  |
| DownloadButton | DownloadButton |  |
| Dropdown |  | dropdown |
| EmptyState | EmptyState |  |
| ErrorBar | ErrorBar |  |
| FeatureBulletItem | FeatureBulletItem |  |
| Field | Field |  |
| FileListItem | FileListItem |  |
| FileMetadataCard | FileMetadataCard |  |
| FileUploader | FileUploader |  |
| FilterLegend | FilterLegend |  |
| FloatingActionButton |  | floatingActionButton |
| FullWidthSearchInput | FullWidthSearchInput |  |
| HeaderSearchInput | HeaderSearchInput |  |
| HistoryTimeline | HistoryTimeline |  |
| Hyperlink | Hyperlink |  |
| IconBox | IconBox |  |
| IconButton | IconButton | iconButton |
| InlineStat | InlineStat |  |
| LoadingSpinner |  | activityIndicator |
| LoadMore | LoadMore |  |
| MenuButton | MenuButton |  |
| MenuPopover | MenuPopover (with MenuItem) |  |
| MetaInfo | MetaInfo |  |
| ModelAvatarStack | ModelAvatarStack |  |
| NavigationMenu | NavigationMenu |  |
| NotificationBadge | NotificationBadge |  |
| NumberInput | NumberInput |  |
| OnboardingBanner | OnboardingBanner |  |
| OptionIcon | OptionIcon |  |
| PageControl | PageControl |  |
| Pagination |  | pagination |
| Panel | Panel |  |
| PaneToolbar | PaneToolbar |  |
| PersonChip | PersonChip |  |
| ProgressIndicator | ProgressBar | progressBar |
| PromptBanner | PromptBanner |  |
| PromptInput | PromptInput |  |
| ProviderCard | ProviderCard |  |
| ProviderIcon | ProviderIcon |  |
| ProviderPill | ProviderPill |  |
| PulsingDots | PulsingDots |  |
| RadialProgress | RadialProgress |  |
| RadioButton | Radio | radio |
| ResourceChip | ResourceChip |  |
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
| Skeleton | Skeleton |  |
| Slider | Slider | slider |
| SortMenu | SortMenu |  |
| SplitButton | SplitButton |  |
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
| Switch | Switch | switch |
| TabBarWithBadges | TabBarWithBadges |  |
| Table |  | tableView |
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
| Tooltip | Tooltip | tooltip behavior |
| TrialBanner | TrialBanner |  |
| UpgradeButton | UpgradeButton |  |
| UserMenu | UserMenu |  |
| WindowToolbar | WindowToolbar |  |

Also here with no source file of the same name: Card, ListRow, SectionHeader, Tabs.

## Still to rebuild

In the order planned: what generated UI reaches for first, then the application chrome.

### Text and small content (1)

CodePreview

### Cards and rows (2)

FolderCard, ResourceCard

### Inputs (12)

Combobox, NumberPresetInput, ExtensionChipsInput, ImageUpload, IconSelect, IconSegmentedControl, DropdownMultiselect, MultiSelectDropdown, HierarchicalPicker, RichTextField, RichTextToolbar, PromptInputWithBanner

### Navigation and chrome (8)

BrowserTabs, TabOverflowScroll, SplitPaneTabs, SidebarTogglePattern, Toolbar, CollapsibleSection, CanvasShell, ResizableRow

### Menus and overlays (9)

AddContextMenu, FileTreeContextMenu, ModelSelectMenu, ProjectSelector, WorkspaceSwitcher, NotePopover, SlidingPanel, ViewerDialog, VariableContractHover

### Data and specialized (11)

Tree, FileTree, DateTimelineAxis, ImageGallery, NestedTaskLedger, ReorderableList, ReorderGhost, SuggestionReviewItem, CompactSuggestionReviewItem, SuggestionActionObject, VariableContractList
