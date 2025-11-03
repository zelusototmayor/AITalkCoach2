import React, { useState, useMemo, useEffect } from 'react';
import { View, Text, StyleSheet, ScrollView, TextInput, TouchableOpacity, FlatList, ActivityIndicator, RefreshControl } from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';
import { Ionicons } from '@expo/vector-icons';
import AnimatedBackground from '../../components/AnimatedBackground';
import BottomNavigation from '../../components/BottomNavigation';
import PromptListCard from '../../components/PromptListCard';
import { COLORS, SPACING, TYPOGRAPHY } from '../../constants/colors';
import { getPrompts } from '../../services/api';

export default function PromptsScreen({ navigation }) {
  const [searchQuery, setSearchQuery] = useState('');
  const [selectedCategory, setSelectedCategory] = useState('all');
  const [prompts, setPrompts] = useState([]);
  const [loading, setLoading] = useState(true);
  const [refreshing, setRefreshing] = useState(false);
  const [error, setError] = useState(null);

  useEffect(() => {
    loadPrompts();
  }, []);

  const loadPrompts = async () => {
    try {
      setError(null);
      const data = await getPrompts();
      setPrompts(data.prompts || []);
    } catch (err) {
      console.error('Error loading prompts:', err);
      setError(err.message);
    } finally {
      setLoading(false);
      setRefreshing(false);
    }
  };

  const handleRefresh = () => {
    setRefreshing(true);
    loadPrompts();
  };

  const categories = useMemo(() => {
    const cats = ['all'];
    const uniqueCats = [...new Set(prompts.map(p => p.category))].sort();
    return [...cats, ...uniqueCats];
  }, [prompts]);


  const handlePractice = (prompt) => {
    navigation.navigate('Practice', {
      presetDuration: prompt.duration,
      promptText: prompt.prompt_text,
      promptTitle: prompt.title,
    });
  };

  const filteredPrompts = useMemo(() => {
    return prompts.filter(prompt => {
      const matchesSearch = searchQuery === '' ||
        prompt.title.toLowerCase().includes(searchQuery.toLowerCase()) ||
        prompt.description.toLowerCase().includes(searchQuery.toLowerCase()) ||
        prompt.prompt_text.toLowerCase().includes(searchQuery.toLowerCase());

      const matchesCategory = selectedCategory === 'all' ||
        prompt.category === selectedCategory;

      return matchesSearch && matchesCategory;
    });
  }, [searchQuery, selectedCategory, prompts]);

  if (loading) {
    return (
      <SafeAreaView style={styles.container} edges={['top', 'bottom']}>
        <AnimatedBackground />
        <View style={styles.loadingContainer}>
          <ActivityIndicator size="large" color={COLORS.primary} />
          <Text style={styles.loadingText}>Loading prompts...</Text>
        </View>
        <BottomNavigation activeScreen="prompts" />
      </SafeAreaView>
    );
  }

  if (error) {
    return (
      <SafeAreaView style={styles.container} edges={['top', 'bottom']}>
        <AnimatedBackground />
        <View style={styles.errorContainer}>
          <Ionicons name="alert-circle-outline" size={48} color={COLORS.danger} />
          <Text style={styles.errorText}>Error loading prompts</Text>
          <Text style={styles.errorSubtext}>{error}</Text>
          <TouchableOpacity style={styles.retryButton} onPress={loadPrompts}>
            <Text style={styles.retryButtonText}>Retry</Text>
          </TouchableOpacity>
        </View>
        <BottomNavigation activeScreen="prompts" />
      </SafeAreaView>
    );
  }

  return (
    <SafeAreaView style={styles.container} edges={['top', 'bottom']}>
      <AnimatedBackground />

      <View style={styles.content}>
        <Text style={styles.title}>Practice Prompts</Text>

        {/* Search Bar */}
        <View style={styles.searchContainer}>
          <Ionicons name="search" size={20} color={COLORS.textSecondary} />
          <TextInput
            style={styles.searchInput}
            placeholder="Search prompts..."
            placeholderTextColor={COLORS.textSecondary}
            value={searchQuery}
            onChangeText={setSearchQuery}
          />
          {searchQuery !== '' && (
            <TouchableOpacity onPress={() => setSearchQuery('')}>
              <Ionicons name="close-circle" size={20} color={COLORS.textSecondary} />
            </TouchableOpacity>
          )}
        </View>

        {/* Category Filter */}
        <ScrollView
          horizontal
          showsHorizontalScrollIndicator={false}
          style={styles.categoryScroll}
          contentContainerStyle={styles.categoryScrollContent}
        >
          {categories.map(category => (
            <TouchableOpacity
              key={category}
              style={[
                styles.categoryChip,
                selectedCategory === category && styles.categoryChipSelected,
              ]}
              onPress={() => setSelectedCategory(category)}
              activeOpacity={0.7}
            >
              <Text
                style={[
                  styles.categoryChipText,
                  selectedCategory === category && styles.categoryChipTextSelected,
                ]}
                numberOfLines={1}
              >
                {category === 'all' ? 'All' : category}
              </Text>
            </TouchableOpacity>
          ))}
        </ScrollView>

        {/* Prompts List */}
        <FlatList
          style={styles.flatList}
          data={filteredPrompts}
          keyExtractor={(item) => item.id.toString()}
          renderItem={({ item }) => (
            <PromptListCard
              category={item.category}
              title={item.title}
              description={item.description}
              promptText={item.prompt_text}
              duration={item.duration}
              focusAreas={item.focus_areas}
              onPractice={() => handlePractice(item)}
            />
          )}
          contentContainerStyle={styles.listContent}
          showsVerticalScrollIndicator={false}
          refreshControl={
            <RefreshControl refreshing={refreshing} onRefresh={handleRefresh} />
          }
          ListEmptyComponent={
            <View style={styles.emptyState}>
              <Ionicons name="search-outline" size={48} color={COLORS.textSecondary} />
              <Text style={styles.emptyText}>No prompts found</Text>
              <Text style={styles.emptySubtext}>Try adjusting your filters</Text>
            </View>
          }
        />
      </View>

      <BottomNavigation activeScreen="prompts" />
    </SafeAreaView>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: COLORS.background,
  },
  content: {
    flex: 1,
    paddingTop: SPACING.lg,
  },
  title: {
    ...TYPOGRAPHY.heading,
    color: COLORS.text,
    marginBottom: SPACING.md,
    paddingHorizontal: SPACING.lg,
  },
  searchContainer: {
    flexDirection: 'row',
    alignItems: 'center',
    backgroundColor: COLORS.cardBackground,
    borderRadius: 12,
    borderWidth: 1,
    borderColor: COLORS.border,
    paddingHorizontal: SPACING.md,
    paddingVertical: SPACING.sm,
    marginHorizontal: SPACING.lg,
    marginBottom: SPACING.sm,
  },
  searchInput: {
    flex: 1,
    fontSize: 15,
    color: COLORS.text,
    marginLeft: SPACING.xs,
    paddingVertical: 4,
  },
  categoryScroll: {
    marginBottom: SPACING.xl,
    flexGrow: 0,
  },
  flatList: {
    flex: 1,
  },
  categoryScrollContent: {
    paddingHorizontal: SPACING.lg,
    paddingRight: SPACING.xl,
  },
  categoryChip: {
    paddingHorizontal: SPACING.md,
    paddingVertical: 8,
    borderRadius: 20,
    backgroundColor: COLORS.cardBackground,
    borderWidth: 1,
    borderColor: COLORS.border,
    marginRight: SPACING.sm,
    height: 36,
    justifyContent: 'center',
    alignItems: 'center',
    flexShrink: 0,
  },
  categoryChipSelected: {
    backgroundColor: COLORS.primary,
    borderColor: COLORS.primary,
  },
  categoryChipText: {
    fontSize: 14,
    fontWeight: '600',
    color: COLORS.textSecondary,
    flexShrink: 0,
  },
  categoryChipTextSelected: {
    color: '#FFFFFF',
  },
  listContent: {
    paddingTop: SPACING.md,
    paddingHorizontal: SPACING.lg,
    paddingBottom: 100,
  },
  emptyState: {
    flex: 1,
    justifyContent: 'center',
    alignItems: 'center',
    paddingVertical: SPACING.xxl * 2,
  },
  emptyText: {
    fontSize: 16,
    fontWeight: '600',
    color: COLORS.text,
    marginTop: SPACING.sm,
  },
  emptySubtext: {
    fontSize: 14,
    color: COLORS.textSecondary,
    marginTop: 4,
  },
  loadingContainer: {
    flex: 1,
    justifyContent: 'center',
    alignItems: 'center',
  },
  loadingText: {
    marginTop: SPACING.md,
    fontSize: 16,
    color: COLORS.textSecondary,
  },
  errorContainer: {
    flex: 1,
    justifyContent: 'center',
    alignItems: 'center',
    paddingHorizontal: SPACING.xl,
  },
  errorText: {
    fontSize: 18,
    fontWeight: '600',
    color: COLORS.text,
    marginTop: SPACING.md,
    marginBottom: SPACING.xs,
  },
  errorSubtext: {
    fontSize: 14,
    color: COLORS.textSecondary,
    textAlign: 'center',
    marginBottom: SPACING.xl,
  },
  retryButton: {
    backgroundColor: COLORS.primary,
    paddingHorizontal: SPACING.xl,
    paddingVertical: SPACING.sm,
    borderRadius: 8,
  },
  retryButtonText: {
    color: '#FFFFFF',
    fontSize: 16,
    fontWeight: '600',
  },
});
